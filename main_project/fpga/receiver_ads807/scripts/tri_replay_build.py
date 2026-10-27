"""Build isolated, fixed-authority EP4CE6 TRI1 ROM replay configurations."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from main_project.fpga.receiver_ads807.host.replay import waveform

SOURCE = PROJECT / "main_project/fpga/receiver_ads807_tri"
OUTPUT = PROJECT / ".harness/tri_board_test"
MODES = {"auto": 0, "fpga": 1, "manual": 2}


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError("Source baseline changed: " + old[:100])
    return text.replace(old, new, 1)


def prepare(mode):
    root = OUTPUT / mode / "project"
    root.mkdir(parents=True, exist_ok=True)
    for directory in ("rtl", "ip"):
        shutil.copytree(SOURCE / directory, root / directory, dirs_exist_ok=True)
    shutil.copyfile(SOURCE / "board_pins.tcl", root / "board_pins.tcl")
    top = (root / "rtl/receiver_top.v").read_text()
    top = replace_once(top, "    input wire [11:0] adc_data,\n    output wire adc_clk,\n", "")
    top = replace_once(top, "    assign adc_clk = sample_clk;", "")
    top = replace_once(top, "    reg [11:0] adc_registered;", """    reg [11:0] adc_registered;
    wire [11:0] replay_data;
    reg [11:0] replay_address;
    altsyncram #(
        .operation_mode("ROM"), .width_a(12), .widthad_a(12), .numwords_a(4096),
        .outdata_reg_a("UNREGISTERED"), .address_aclr_a("NONE"),
        .outdata_aclr_a("NONE"), .init_file("rtl/replay.mif"),
        .intended_device_family("Cyclone IV E"), .lpm_type("altsyncram")
    ) replay_memory(
        .clock0(sample_clk), .address_a(replay_address), .q_a(replay_data),
        .clocken0(1'b1), .aclr0(1'b0), .rden_a(1'b1), .wren_a(1'b0),
        .data_a(12'd0), .byteena_a(1'b1)
    );
    always @(posedge sample_clk) begin
        if (!sample_rst_n) begin
            replay_address <= 0;
        end else begin
            replay_address <= replay_address + 1'b1;
        end
    end""")
    top = replace_once(top, "        adc_registered <= adc_data;", "        adc_registered <= replay_data;")
    # The board replay revision uses commands for start/stop; PA1 is not a pause input.
    top = replace_once(top, "pause_sync <= {pause_sync[0], usb_pa1};", "pause_sync <= 0;")
    (root / "rtl/receiver_top.v").write_text(top, encoding="ascii")
    control = (root / "rtl/rx_control.v").read_text()
    control = replace_once(control, "            mode <= 0;", f"            mode <= 2'd{MODES[mode]};")
    control = replace_once(control, "if (argument > 2)", f"if (argument != {MODES[mode]})")
    control = replace_once(control, "mode <= argument[1:0];", f"mode <= 2'd{MODES[mode]};")
    (root / "rtl/rx_control.v").write_text(control, encoding="ascii")
    fifo = (root / "rtl/rx_fifo_tri.v").read_text()
    fifo = replace_once(fifo, ".lpm_numwords(512)", ".lpm_numwords(256)")
    fifo = replace_once(fifo, ".lpm_widthu(9)", ".lpm_widthu(8)")
    (root / "rtl/rx_fifo_tri.v").write_text(fifo, encoding="ascii")
    # Payload is held in the source register until the destination consumes it.
    # Removing the duplicate destination bank retains the synchronized valid/ACK.
    mailbox = (root / "rtl/rx_mailbox.v").read_text()
    mailbox = replace_once(mailbox, "output reg [WIDTH-1:0] dst_data", "output wire [WIDTH-1:0] dst_data")
    mailbox = replace_once(mailbox, "    reg [WIDTH-1:0] held_data;", "    reg [WIDTH-1:0] held_data;\n    assign dst_data = held_data;")
    mailbox = replace_once(mailbox, "            dst_data <= 0;\n", "")
    mailbox = replace_once(mailbox, "                dst_data <= held_data;\n", "")
    (root / "rtl/rx_mailbox.v").write_text(mailbox, encoding="ascii")
    packet = (root / "rtl/rx_tri_packet.v").read_text()
    packet = replace_once(packet, "    reg [31:0] header_word;", "    reg [31:0] header_word;\n    reg [31:0] response_word;")
    cases = "\n".join(f"            {n}: response_word = response[{32*n+31}:{32*n}];" for n in range(12))
    packet = replace_once(packet, "    always @* begin", "    always @* begin\n        case (fill_word)\n" + cases + "\n            default: response_word = 0;\n        endcase\n    end\n    always @* begin")
    packet = replace_once(packet, "payload[fill_word] <= response >> (32*fill_word);", "payload[fill_word] <= response_word;")
    (root / "rtl/rx_tri_packet.v").write_text(packet, encoding="ascii")
    qsf = (SOURCE / "receiver_ads807_tri.qsf").read_text()
    qsf = qsf.replace("EP4CE10F17C8", "EP4CE6F17C8")
    qsf = re.sub(r"set_global_assignment -name PROJECT_OUTPUT_DIRECTORY .*", "set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output", qsf)
    qsf = "\n".join(line for line in qsf.splitlines() if "VIRTUAL_PIN" not in line)
    (root / "receiver_ads807_tri.qsf").write_text(qsf + "\n", encoding="ascii")
    (root / "receiver_ads807_tri.qpf").write_text('PROJECT_REVISION = "receiver_ads807_tri"\n', encoding="ascii")
    sdc = (SOURCE / "receiver_ads807_tri.sdc").read_text()
    # Match the already validated replay board's conservative control requirements.
    sdc = sdc.replace("-max 12.1", "-max 12.7").replace("-min -3.6", "-min -3.7")
    sdc = "\n".join(line for line in sdc.splitlines() if "pause_sync" not in line and "command_mailbox|dst_data" not in line and "response_mailbox|dst_data" not in line)
    sdc += "\n# Held payloads remain stable until consumption ACK; valid crosses two stages.\n"
    sdc += "set_max_delay 20.0 -from [get_registers {*command_mailbox|held_data[*]}] -to [get_registers {*control|*}]\n"
    sdc += "set_max_delay 35.0 -from [get_registers {*response_mailbox|held_data[*]}] -to [get_registers {*packet|*}]\n"
    sdc += "set_max_delay 35.0 -from [get_registers {*snapshot|held_id[*]}] -to [get_registers {*snapshot|completed_id[*]}]\n"
    (root / "receiver_ads807_tri.sdc").write_text(sdc, encoding="ascii")
    return root


def run_tool(quartus, root, command, label):
    with (root.parent / (label + ".log")).open("w", encoding="utf-8") as log:
        result = subprocess.run([str(quartus / "bin64" / command[0]), *command[1:]],
                                cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    if result.returncode:
        raise RuntimeError(f"{label} failed: {root.parent / (label + '.log')}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    parser.add_argument("--mode", choices=tuple(MODES), default="auto")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    if args.mode == "fpga":
        baseline = PROJECT / ".harness/receiver_replay"
        evidence = json.loads((baseline / "build.json").read_text())
        sof = baseline / "quartus/receiver_replay.sof"
        digest = hashlib.sha256(sof.read_bytes()).hexdigest()
        if evidence["status"] != "PASS" or digest != evidence["sha256"]:
            raise ValueError("Existing autonomous replay SOF is not verified")
        cases = []
        for kind, amplitude in (("am", 800), ("fm", 800), ("am", 80), ("fm", 80)):
            _, info = waveform(kind, amplitude=amplitude)
            info.update(name=f"fpga_{kind}_{amplitude}", mode="fpga", mode_id=1,
                        sof=str(sof), sha256=digest, usb_protocol="RPL1", fifo_samples=512,
                        minimum_slack_ns=evidence["minimum_slack_ns"],
                        input="USB preload ADC12 RAM; physical ADC not used")
            cases.append(info)
        destination = OUTPUT / "fpga/cases.json"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(cases, indent=2), encoding="utf-8")
        print(json.dumps(cases, indent=2), flush=True)
        return
    root = prepare(args.mode)
    cases = []
    for kind, amplitude in (("am", 800), ("fm", 800), ("am", 80), ("fm", 80)):
        samples, info = waveform(kind, length=4096, amplitude=amplitude)
        contents = "\n".join(f"{n:03X} : {v:03X};" for n, v in enumerate(samples))
        (root / "rtl/replay.mif").write_text("WIDTH=12;\nDEPTH=4096;\nADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n" + contents + "\nEND;\n", encoding="ascii")
        name = f"{args.mode}_{kind}_{amplitude}"
        if not cases:
            if args.prepare_only:
                print(root)
                return
            print("Compiling " + name, flush=True)
            run_tool(args.quartus, root, ["quartus_sh.exe", "--flow", "compile", "receiver_ads807_tri"], "compile")
            fit = (root / "output/receiver_ads807_tri.fit.summary").read_text()
            if "Device : EP4CE6F17C8" not in fit or "Fitter Status : Successful" not in fit:
                raise ValueError("Wrong device or failed fit")
            sta = (root / "output/receiver_ads807_tri.sta.summary").read_text()
            slacks = [float(v) for v in re.findall(r"Slack\s*:\s*([\d.-]+)", sta)]
            if len(slacks) < 30 or min(slacks) < 0:
                raise ValueError("Missing or negative timing checks: " + str(slacks))
        else:
            print("Updating ROM " + name, flush=True)
            run_tool(args.quartus, root, ["quartus_cdb.exe", "receiver_ads807_tri", "--update_mif"], name + "_rom")
            run_tool(args.quartus, root, ["quartus_asm.exe", "receiver_ads807_tri"], name + "_asm")
        destination = root.parent / (name + ".sof")
        shutil.copyfile(root / "output/receiver_ads807_tri.sof", destination)
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        if any(case["sha256"] == digest for case in cases):
            raise ValueError("ROM update did not change SOF")
        info.update(name=name, mode=args.mode, mode_id=MODES[args.mode], sof=str(destination),
                    source="FPGA ROM ADC12 replay", protocol="TRI1", sha256=digest, minimum_slack_ns=min(slacks),
                    fifo_samples=256, input="FPGA ROM ADC12; physical ADC not used")
        cases.append(info)
        (root.parent / "cases.json").write_text(json.dumps(cases, indent=2), encoding="utf-8")
    print(json.dumps(cases, indent=2), flush=True)


if __name__ == "__main__":
    main()
