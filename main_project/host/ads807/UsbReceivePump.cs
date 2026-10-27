using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using CyUSB;

namespace Ads807Transport
{
    // Follow Cypress Streamer's pinned Begin/Wait/FinishDataXfer lifecycle.
    public sealed class UsbReceivePump : IDisposable
    {
        private sealed class Slot
        {
            public byte[] Command;
            public byte[] Data = new byte[512];
            public byte[] Overlap;
            public GCHandle CommandPin, DataPin, OverlapPin;
            public IntPtr Event;
            public bool Pending;
        }

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr CreateEvent(IntPtr attributes, bool manualReset, bool initialState, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        private readonly CyUSBEndPoint endpoint;
        private readonly BlockingCollection<byte[]> packets = new BlockingCollection<byte[]>(128);
        private readonly Thread worker;
        private readonly object metrics = new object();
        private readonly Slot[] slots = new Slot[128];
        private volatile bool stopping;
        private string error = "";
        private long calls, droppedBytes, gaps512, gaps1024;
        private double maxGapMs, maxReadMs;
        private byte[] batch = new byte[32768];
        private int batchCount;

        public UsbReceivePump(CyUSBEndPoint input)
        {
            endpoint = input;
            worker = new Thread(Receive);
            worker.IsBackground = true;
            worker.Name = "ads807-overlapped-usb-in";
            worker.Start();
        }

        public int QueueDepth { get { return slots.Length; } }
        public string Error { get { lock (metrics) { return error; } } }
        public long DroppedBytes { get { lock (metrics) { return droppedBytes; } } }
        public double[] Timing()
        {
            lock (metrics)
            {
                return new double[] { calls, maxGapMs, maxReadMs, gaps512, gaps1024, droppedBytes, packets.Count };
            }
        }

        public byte[] Read(int timeoutMs)
        {
            byte[] packet;
            if (packets.TryTake(out packet, timeoutMs)) return packet;
            if (Error.Length != 0) throw new InvalidOperationException(Error);
            return null;
        }

        private void Submit(Slot slot)
        {
            int length = slot.Data.Length;
            if (!endpoint.BeginDataXfer(ref slot.Command, ref slot.Data, ref length, ref slot.Overlap))
                throw new InvalidOperationException("BeginDataXfer failed: " + endpoint.LastError);
            slot.Pending = true;
        }

        private void FlushBatch()
        {
            if (batchCount == 0) return;
            byte[] data = batch;
            if (batchCount != data.Length) Array.Resize(ref data, batchCount);
            if (!packets.TryAdd(data))
            {
                lock (metrics) { droppedBytes += batchCount; }
            }
            batch = new byte[32768];
            batchCount = 0;
        }

        private void Receive()
        {
            double tickMs = 1000.0 / Stopwatch.Frequency;
            try
            {
                for (int index = 0; index < slots.Length; index++)
                {
                    Slot slot = new Slot();
                    slots[index] = slot;
                    slot.Command = new byte[CyConst.SINGLE_XFER_LEN + (endpoint.XferMode == XMODE.BUFFERED ? 512 : 0)];
                    slot.Overlap = new byte[Math.Max(CyConst.OverlapSignalAllocSize, Marshal.SizeOf(typeof(OVERLAPPED)))];
                    slot.CommandPin = GCHandle.Alloc(slot.Command, GCHandleType.Pinned);
                    slot.DataPin = GCHandle.Alloc(slot.Data, GCHandleType.Pinned);
                    slot.OverlapPin = GCHandle.Alloc(slot.Overlap, GCHandleType.Pinned);
                    slot.Event = CreateEvent(IntPtr.Zero, false, false, null);
                    if (slot.Event == IntPtr.Zero) throw new InvalidOperationException("CreateEvent failed");
                    OVERLAPPED overlap = new OVERLAPPED();
                    overlap.hEvent = slot.Event;
                    Marshal.StructureToPtr(overlap, slot.OverlapPin.AddrOfPinnedObject(), false);
                    Submit(slot);
                }

                int current = 0;
                while (!stopping)
                {
                    Slot slot = slots[current];
                    long start = Stopwatch.GetTimestamp();
                    if (!endpoint.WaitForXfer(slot.Event, 25))
                    {
                        // Keep requests queued while flushing a short ACK/RAW batch.
                        FlushBatch();
                        continue;
                    }
                    int count = slot.Data.Length;
                    bool ok = endpoint.FinishDataXfer(ref slot.Command, ref slot.Data, ref count, ref slot.Overlap);
                    slot.Pending = false;
                    long finished = Stopwatch.GetTimestamp();
                    if (!ok || count < 0 || count > slot.Data.Length)
                        throw new InvalidOperationException("FinishDataXfer failed: error=" + endpoint.LastError + " bytes=" + count);
                    if (count > 0)
                    {
                        Buffer.BlockCopy(slot.Data, 0, batch, batchCount, count);
                        batchCount += count;
                    }
                    Submit(slot);
                    long submitted = Stopwatch.GetTimestamp();
                    lock (metrics)
                    {
                        double gap = (submitted-finished)*tickMs;
                        calls++;
                        maxGapMs = Math.Max(maxGapMs, gap);
                        maxReadMs = Math.Max(maxReadMs, (finished-start)*tickMs);
                        if (gap > 0.512) gaps512++;
                        if (gap > 1.024) gaps1024++;
                    }
                    if (batchCount == batch.Length) FlushBatch();
                    current = (current+1) % slots.Length;
                }
            }
            catch (Exception failure)
            {
                lock (metrics) { error = failure.ToString(); }
            }
            finally
            {
                try
                {
                    endpoint.Abort();
                    foreach (Slot slot in slots)
                    {
                        if (slot == null) continue;
                        if (slot.Pending)
                        {
                            if (!endpoint.WaitForXfer(slot.Event, 1000))
                            {
                                lock (metrics) { error = "USB cancellation not confirmed; pinned request retained"; }
                                continue;
                            }
                            int count = slot.Data.Length;
                            endpoint.FinishDataXfer(ref slot.Command, ref slot.Data, ref count, ref slot.Overlap);
                            slot.Pending = false;
                        }
                        if (slot.Event != IntPtr.Zero) CloseHandle(slot.Event);
                        if (slot.OverlapPin.IsAllocated) slot.OverlapPin.Free();
                        if (slot.DataPin.IsAllocated) slot.DataPin.Free();
                        if (slot.CommandPin.IsAllocated) slot.CommandPin.Free();
                    }
                }
                catch (Exception failure) { lock (metrics) { error = failure.ToString(); } }
                packets.CompleteAdding();
            }
        }

        public void Dispose()
        {
            stopping = true;
            worker.Join();
            if (Error.Length != 0) throw new InvalidOperationException(Error);
        }
    }
}
