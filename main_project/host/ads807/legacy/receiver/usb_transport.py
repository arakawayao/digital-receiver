"""FX2 EP6 OUT / EP2 IN transports. No driver replacement or firmware loading."""
import ctypes
import os
import time
from pathlib import Path

EP_OUT=0x06
EP_IN=0x82
class TransferTimeout(TimeoutError):pass

def cyusb_path(explicit=None):
    if explicit:
        p=Path(explicit)
        if not p.is_file():raise RuntimeError(f'CyUSB.dll not found: {p}')
        return p
    root=Path(os.environ.get('ProgramFiles(x86)',r'C:\Program Files (x86)'))/'Cypress'
    found=sorted(root.glob('EZ-USB FX3 SDK/*/library/c_sharp/lib/CyUSB.dll'))
    if not found:raise RuntimeError('Official CyUSB.dll not found; specify --cyusb-dll PATH')
    return found[-1]

class CyUSBTransport:
    def __init__(self,vid,pid,interface=0,dll=None):
        if interface!=0:raise RuntimeError('CyUSB adapter currently supports interface 0 only')
        try:
            import clr
            from System import Array,Byte,Int32
            from System.Runtime.InteropServices import GCHandle,GCHandleType
        except ImportError as e:raise RuntimeError('Cypress backend requires: python -m pip install pythonnet') from e
        self.dll=cyusb_path(dll)
        clr.AddReference(str(self.dll))
        from CyUSB import USBDeviceList,CyConst
        self.Array,self.Byte,self.Int32=Array,Byte,Int32
        self.GCHandle,self.GCHandleType=GCHandle,GCHandleType
        self.devices=USBDeviceList(CyConst.DEVICES_CYUSB)
        try:
            candidates=[self.devices[i] for i in range(self.devices.Count)]
            candidates=[d for d in candidates if d is not None and d.VendorID==vid and d.ProductID==pid]
            if len(candidates)!=1:raise RuntimeError(f'Cypress backend found {len(candidates)} matching devices; connect exactly one')
            self.device=candidates[0]
            self.endpoints={int(e.Address):e for e in self.device.EndPoints if e is not None}
            if self.device.AltIntfc!=0:raise RuntimeError('Select firmware alternate interface 0 first')
            if not {EP_OUT,EP_IN}<=self.endpoints.keys():
                raise RuntimeError('Firmware must expose EP6 OUT 0x06 and EP2 IN 0x82; found '+str([hex(a) for a in self.endpoints]))
            if not self.device.bHighSpeed or any(int(self.endpoints[a].Attributes)&3!=2 or int(self.endpoints[a].MaxPktSize)!=512 for a in (EP_OUT,EP_IN)):
                raise RuntimeError('Expected high-speed bulk endpoints with 512-byte max packets')
        except Exception:
            self.close();raise
    def describe(self):
        return dict(backend='cyusb',dll=str(self.dll),vid=hex(self.device.VendorID),pid=hex(self.device.ProductID),
                    device=str(self.device.FriendlyName),ep_out=hex(EP_OUT),ep_in=hex(EP_IN),max_packet=512,high_speed=True)
    def vendor_command(self,request,timeout=1000):
        # FCore2S vendor example: device-directed, vendor OUT, no data stage.
        ep=self.device.ControlEndPt
        ep.Target=0;ep.ReqType=0x40;ep.Direction=0
        ep.ReqCode=request;ep.Value=0;ep.Index=0;ep.TimeOut=timeout
        ok,_,count=ep.XferData(self.Array[self.Byte]([0]),self.Int32(0))
        if not ok or int(count)!=0:
            raise RuntimeError(f'FX2 vendor command {request:#04x} failed: LastError={ep.LastError}, NtStatus={ep.NtStatus:#x}, UsbdStatus={ep.UsbdStatus:#x}')
    def _transfer(self,address,buffer,length,timeout):
        ep=self.endpoints[address];ep.TimeOut=timeout
        start=time.monotonic()
        ok,data,count=ep.XferData(buffer,self.Int32(length))
        elapsed_ms=round((time.monotonic()-start)*1000)
        count=int(count)
        if not ok:
            detail=f'EP {address:#04x}: LastError={ep.LastError}, NtStatus={ep.NtStatus:#x}, UsbdStatus={ep.UsbdStatus:#x}, bytes={count}/{length}, elapsed_ms={elapsed_ms}, timeout_ms={timeout}'
            timed_out=(int(ep.LastError) in (121,997,1460) or int(ep.NtStatus) in (0x3e3,0xc00000b5) or elapsed_ms>=timeout*.8)
            # Bulk IN may return useful complete packets before the requested
            # aggregate buffer fills. Preserve those bytes instead of dropping
            # them when CyUSB reports ERROR_IO_PENDING / STATUS_PENDING timeout.
            if address==EP_IN and count>0 and timed_out:return data,count
            if count==0 and timed_out:raise TransferTimeout(detail)
            raise RuntimeError('Cypress USB transfer failed: '+detail)
        if not 0<=count<=length:raise RuntimeError('Invalid Cypress transfer length')
        return data,count
    def read(self,address,size,timeout=1000):
        if address!=EP_IN:raise ValueError('Read requires EP2 IN 0x82')
        buffer=self.Array.CreateInstance(self.Byte,size)
        data,count=self._transfer(address,buffer,size,timeout)
        handle=self.GCHandle.Alloc(data,self.GCHandleType.Pinned)
        try:return ctypes.string_at(handle.AddrOfPinnedObject().ToInt64(),count)
        finally:handle.Free()
    def write(self,address,data,timeout=3000):
        if address!=EP_OUT:raise ValueError('Write requires EP6 OUT 0x06')
        _,count=self._transfer(address,self.Array[self.Byte](data),len(data),timeout)
        return count
    def close(self):
        if self.devices is not None:self.devices.Dispose();self.devices=None

class PyUSBTransport:
    def __init__(self,vid,pid,interface=0,dll=None):
        try:
            import usb.core
            import usb.util
        except ImportError as e:raise RuntimeError('PyUSB backend requires: python -m pip install pyusb libusb-package') from e
        self.core,self.util=usb.core,usb.util
        try:
            import libusb_package
            backend=libusb_package.get_libusb1_backend()
        except ImportError:backend=None
        self.dev=usb.core.find(idVendor=vid,idProduct=pid,backend=backend)
        if self.dev is None:raise RuntimeError('PyUSB did not find the specified FX2')
        try:
            cfg=self.dev.get_active_configuration()
            eps={e.bEndpointAddress:e for e in cfg[(interface,0)]}
            if not {EP_OUT,EP_IN}<=eps.keys():raise RuntimeError('Need EP6 OUT 0x06 and EP2 IN 0x82')
            if any((eps[a].bmAttributes&3)!=2 or eps[a].wMaxPacketSize!=512 for a in (EP_OUT,EP_IN)):
                raise RuntimeError('Expected high-speed bulk endpoints with 512-byte max packets')
            usb.util.claim_interface(self.dev,interface)
        except Exception:self.close();raise
    def describe(self):return dict(backend='pyusb',vid=hex(self.dev.idVendor),pid=hex(self.dev.idProduct),ep_out=hex(EP_OUT),ep_in=hex(EP_IN),max_packet=512)
    def vendor_command(self,request,timeout=1000):
        self.dev.ctrl_transfer(0x40,request,0,0,b'',timeout=timeout)
    def read(self,address,size,timeout=1000):
        try:return bytes(self.dev.read(address,size,timeout=timeout))
        except self.core.USBTimeoutError as e:raise TransferTimeout(str(e)) from e
    def write(self,address,data,timeout=3000):return self.dev.write(address,data,timeout=timeout)
    def close(self):
        if self.dev is not None:self.util.dispose_resources(self.dev);self.dev=None

def open_transport(vid,pid,backend='auto',interface=0,dll=None):
    options={'cyusb':CyUSBTransport,'pyusb':PyUSBTransport}
    if backend!='auto':return options[backend](vid,pid,interface,dll)
    order=('cyusb','pyusb') if os.name=='nt' else ('pyusb',)
    errors=[]
    for name in order:
        try:return options[name](vid,pid,interface,dll)
        except Exception as e:errors.append(f'{name}: {e}')
    raise RuntimeError('Cannot open FX2. '+ ' | '.join(errors))
