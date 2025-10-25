import telnetlib
import time
import argparse
import os
import itertools
import threading
import socket
from datetime import datetime

# --- Color Output ---
def apply_colors(text, level="info"):
    if level == "info":
        return f"\033[34m{text}\033[0m"
    elif level == "success":
        return f"\033[32m{text}\033[0m"
    elif level == "error":
        return f"\033[31m{text}\033[0m"
    return text

# --- Logging ---
log_file = None
def log(msg):
    global log_file
    if not log_file:
        os.makedirs("logs", exist_ok=True)
        log_file = f"logs/mmap-{datetime.now().strftime('%Y%m%d-%H%M%S')}.log"
    with open(log_file, "a") as f:
        f.write(f"{datetime.now().isoformat()} {msg}\n")

# --- Argument Parsing ---
parser = argparse.ArgumentParser(description='Telnet Enumeration and CICS Exploit Simulation')
parser.add_argument('-H', '--host', help='Target host IP')
parser.add_argument('-p', '--port', type=int, help='Target port number')
parser.add_argument('-u', '--userfile', help='Path to usernames file')
parser.add_argument('-s', '--screen', action='store_true', help='Display the initial VTAM welcome screen')
parser.add_argument('-M', '--menu', action='store_true', help='Interactive menu')
parser.add_argument('--cicspwn', action='store_true', help='Simulate CICS exploitation')
parser.add_argument('--tso-brute', action='store_true', help='Run TSO brute force script')
parser.add_argument('--script', help='Run specified script (e.g., tso-enum)')
parser.add_argument('--shell-port', type=int, default=4444, help='Backdoor shell listen port')
args = parser.parse_args()

spinning = False

# --- Shared Functions ---
def clear_screen():
    os.system("cls" if os.name == "nt" else "clear")

def spinner():
    for c in itertools.cycle("|/-\\"):
        if not spinning:
            break
        print(f"\rScanning... {c}", end="", flush=True)
        time.sleep(0.1)

def test_login(username):
    try:
        tn = telnetlib.Telnet(args.host, args.port, timeout=15)
        tn.read_until(b"Logon Type:", timeout=10)
        tn.write(b"L TSO\r\n")
        prompt = tn.read_until(b"ENTER USERID", timeout=10).decode("ascii", "ignore")
        if "ENTER USERID" in prompt.upper():
            tn.write(username.encode() + b"\r\n")
            resp = tn.read_until(b"PASSWORD", timeout=3).decode("ascii", "ignore")
            if "PASSWORD" in resp.upper():
                return apply_colors(f"[+] User '{username}' EXISTS.", "success")
            elif "IKJ56420I" in resp:
                return apply_colors(f"[-] User '{username}' does NOT exist.", "error")
            else:
                return apply_colors(f"[?] Ambiguous response for '{username}'.", "info")
        else:
            return apply_colors("[-] Unexpected prompt.", "error")
    except Exception as e:
        return apply_colors(f"[-] Error testing '{username}': {e}", "error")

def enumerate_users():
    global spinning
    if not args.userfile:
        print(apply_colors("[-] User file required for enumeration (--userfile <file>)", "error"))
        return

    spinning = True
    th = threading.Thread(target=spinner)
    th.start()
    with open(args.userfile, "r") as f:
        for user in [l.strip() for l in f if l.strip()]:
            out = test_login(user)
            print(out)
            log(out)
    spinning = False
    th.join()

def display_welcome_screen():
    try:
        tn = telnetlib.Telnet(args.host, args.port, timeout=15)
        ws = tn.read_until(b"Logon Type:", timeout=10).decode("ascii", "ignore")
        print(apply_colors("[+] Welcome Screen:", "info"))
        print(ws)
        log("Displayed welcome screen")
        tn.close()
    except Exception as e:
        err = apply_colors(f"[-] Error: {e}", "error")
        print(err)
        log(str(e))

def run_cicspwn():
    print(apply_colors("[*] Starting CICSPWN simulation", "info"))
    log("CICSPWN simulation start")
    tn = telnetlib.Telnet(args.host, args.port, timeout=10)
    tn.read_until(b"ezCICS", timeout=5)
    tn.write(b"\r\n")

    steps = [
        ("CESN",    "DFHCE3549 Sign-on is complete."),
        ("CEDA",    ""),
        ("DEFINE",  "Resource definition saved (simulated)"),
        ("INSTALL", "All new resource definitions installed successfully."),
        ("F3",      ""),
        ("CEMT",    ""),
        ("INQUIRE FILE", "FILE(FILEA)... FILE(FILEB)..."),
        ("F3",      ""),
        ("CECI",    ""),
        ("WRITEQ",  "Simulated WRITEQ command executed successfully."),
        ("F3",      ""),
        ("CESF",    "DFHCE3590 Sign-off is complete.")
    ]

    for cmd, msg in steps:
        tn.write(cmd.encode() + b"\r\n")
        if msg:
            print(apply_colors(msg, "info"))
            log(msg)
        time.sleep(0.5)

    print(apply_colors("[+] Submitting JCL job...", "info"))
    print(apply_colors("[*] JOB JOB12345 submitted (simulated).", "success"))
    log("Simulated JCL JOB12345")
    tn.close()
    start_shell_listener(args.shell_port)

def start_shell_listener(port):
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.bind(('0.0.0.0', port))
    listener.listen(1)
    print(apply_colors(f"[+] Listener opened on port {port}. Awaiting incoming connection...", "info"))
    conn, addr = listener.accept()
    print(apply_colors(f"[+] Connection received from {addr}. Dropping into restricted shell.", "success"))
    conn.sendall(b"/u/ibmuser $ ")

    while True:
        data = conn.recv(1024)
        if not data:
            break
        cmd = data.decode('ascii', 'ignore').strip().lower()

        if cmd == "whoami":
            conn.sendall(b"IBMUSER\n")
        elif cmd == "ls" or cmd == "ls ~/mfsim/f/ibmuser":
            listing = (
                "file1.txt    job1.jcl    config.cfg    notes.txt\n"
                "report.log   data.csv    archive.zip\n"
            )
            conn.sendall(listing.encode('ascii'))
        elif cmd == "tsocmd rvary":
            conn.sendall(b"SYS1.RACF.DS Primary\n")
        elif cmd == "ps":
            conn.sendall(b"  PID   TCB   STATE   CPU   TIME\n"
                         b" 0001   IPA0   ACTIVE  0.1   00:00:01\n")
        elif cmd == "uname":
            conn.sendall(b"z/OS v3.1\n")
        else:
            conn.sendall(b"Command not recognized in restricted shell.\n")

        conn.sendall(b"/u/ibmuser $ ")

    conn.close()
    listener.close()

def run_tso_brute():
    os.system("python3 tso-brute.py")

# --- CLI Prompts for menu ---
def cli_params(require_userfile=False):
    h = input("Host: ").strip()
    p = input("Port: ").strip()
    try:
        p = int(p)
    except:
        print(apply_colors("[-] Invalid port.", "error"))
        return False
    args.host, args.port = h, p
    if require_userfile:
        uf = input("User file path: ").strip()
        args.userfile = uf
    return True

# --- Interactive Menu ---
def interactive_menu():
    while True:
        clear_screen()
        print("1) View VTAM Screen")
        print("2) Enumerate Users")
        print("3) Run CICSPWN")
        print("4) Run TSO Brute Force")
        print("X) Exit")
        c = input("Choice: ").strip().upper()
        if c == "X":
            break
        if c == "1" and cli_params():
            display_welcome_screen(); input("Enter to continue...")
        elif c == "2" and cli_params(require_userfile=True):
            enumerate_users(); input("Enter to continue...")
        elif c == "3" and cli_params():
            run_cicspwn(); input("Enter to continue...")
        elif c == "4":
            run_tso_brute(); input("Enter to continue...")
        else:
            print(apply_colors("Invalid selection.", "error"))
            time.sleep(1)

# --- Main Execution ---
if args.menu:
    interactive_menu()
elif args.script == "tso-enum" and args.host and args.port and args.userfile:
    enumerate_users()
elif args.cicspwn and args.host and args.port:
    run_cicspwn()
elif args.screen and args.host and args.port:
    display_welcome_screen()
elif args.tso_brute:
    run_tso_brute()
else:
    parser.print_help()
