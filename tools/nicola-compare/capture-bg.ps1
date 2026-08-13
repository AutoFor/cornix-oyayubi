<#
capture-bg.ps1 -- background key logger for long real-world typing sessions (Windows).

Runs a global low-level keyboard hook and records EVERY key event (down/up, high-res
QueryPerformanceCounter time, injected flag, and VK_PACKET unicode) to JSONL, while you
type normally in your real apps. The window stays minimized; just type as usual.
Your backspaces act as natural "something went wrong here" markers.

When you click STOP (restore the window from the taskbar), it saves the log and serves it
on localhost so Claude can read and analyze it through the connected Chrome (no copy-paste).

Usage:
  powershell -ExecutionPolicy Bypass -File .\capture-bg.ps1
  -> minimize the little window, type normally for as long as you want (30 min is fine),
  -> then restore it from the taskbar and click STOP.
  -> tell Claude: "read localhost:8777 and analyze".

Note: over BLE this captures the firmware's OUTPUT (the romaji keycodes it sends) plus timing,
which is enough to spot wrong shift-plane / layer / IME toggles and BLE lag. ASCII-only source.
#>
param(
    [string]$Out = "session-bg.jsonl",
    [switch]$NoServe,
    [int]$Port = 8777
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class KbCaptureBg {
    [DllImport("kernel32.dll")] static extern bool QueryPerformanceCounter(out long c);
    [DllImport("kernel32.dll")] static extern bool QueryPerformanceFrequency(out long f);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, LowLevelKeyboardProc cb, IntPtr mod, uint tid);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int code, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);

    public delegate IntPtr LowLevelKeyboardProc(int code, IntPtr wParam, IntPtr lParam);
    const int WH_KEYBOARD_LL = 13;
    const uint LLKHF_INJECTED = 0x10;

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr extra; }

    static IntPtr _hook = IntPtr.Zero;
    static LowLevelKeyboardProc _proc;
    static long _freq;
    public static List<string> Events = new List<string>();
    static readonly object _lock = new object();

    public static void Start() {
        QueryPerformanceFrequency(out _freq);
        _proc = Hook;
        _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0);
    }
    public static void Stop() {
        if (_hook != IntPtr.Zero) { UnhookWindowsHookEx(_hook); _hook = IntPtr.Zero; }
    }
    public static int Count() { lock (_lock) { return Events.Count; } }

    static IntPtr Hook(int code, IntPtr wParam, IntPtr lParam) {
        if (code >= 0) {
            var k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            int msg = wParam.ToInt32();
            string kind = (msg == 0x100 || msg == 0x104) ? "down" : ((msg == 0x101 || msg == 0x105) ? "up" : "?");
            bool inj = (k.flags & LLKHF_INJECTED) != 0;
            int uni = (k.vkCode == 0xE7) ? (int)k.scanCode : 0;
            long c; QueryPerformanceCounter(out c);
            double t = (double)c * 1000000.0 / (double)_freq;
            string line = "{\"t\":" + t.ToString("F1")
                + ",\"src\":\"raw\",\"kind\":\"" + kind + "\""
                + ",\"vk\":" + k.vkCode + ",\"sc\":" + k.scanCode
                + ",\"inj\":" + (inj ? "true" : "false")
                + (uni != 0 ? (",\"uni\":" + uni) : "") + "}";
            lock (_lock) { Events.Add(line); }
        }
        return CallNextHookEx(IntPtr.Zero, code, wParam, lParam);
    }
}
'@

[KbCaptureBg]::Start()

# Small always-available (but not topmost) status window with a STOP button.
$form = New-Object System.Windows.Forms.Form
$form.Text = "nicola bg logger -- minimize & type; click STOP when done"
$form.Width = 460; $form.Height = 160
$form.TopMost = $false
$form.WindowState = "Minimized"

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "Recording every key. Minimize this and type normally in your apps.`nClick STOP when finished."
$lbl.Dock = "Top"; $lbl.Height = 60
$form.Controls.Add($lbl)

$cnt = New-Object System.Windows.Forms.Label
$cnt.Text = "events: 0"; $cnt.Dock = "Top"; $cnt.Height = 24
$form.Controls.Add($cnt)

$btn = New-Object System.Windows.Forms.Button
$btn.Text = "STOP and save"; $btn.Dock = "Bottom"; $btn.Height = 44
$btn.Add_Click({ $form.Close() })
$form.Controls.Add($btn)

# live event counter
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ $cnt.Text = "events: " + [KbCaptureBg]::Count() })
$timer.Start()

[void][System.Windows.Forms.Application]::Run($form)

$timer.Stop()
[KbCaptureBg]::Stop()

# Save in timestamp order (hook appends in order already, but sort defensively).
$all = New-Object System.Collections.Generic.List[string]
foreach ($l in [KbCaptureBg]::Events) { $all.Add($l) }
$sorted = $all | Sort-Object { [double]([regex]::Match($_, '"t":([0-9.]+)').Groups[1].Value) }
Set-Content -Path $Out -Value $sorted -Encoding UTF8
Write-Host "saved $($sorted.Count) events -> $Out"

if (-not $NoServe) {
    $jsonl = ($sorted -join "`n")
    $html = @"
<!doctype html><meta charset=utf-8><title>nicola bg capture</title>
<body style="font-family:Consolas,monospace;padding:20px">
<h3>nicola bg capture: serving</h3>
<p>events: $($sorted.Count). Tell Claude: "read localhost:$Port and analyze".</p>
<p>raw data: <a href="/data">/data</a></p>
</body>
"@
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
    $listener.Start()
    Write-Host ""
    Write-Host "===================================================================="
    Write-Host " serving: http://localhost:$Port/    (Ctrl+C to stop)"
    Write-Host " -> tell Claude: 'read localhost:$Port and analyze'"
    Write-Host "===================================================================="
    try {
        while ($true) {
            $client = $listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $reqLine = $reader.ReadLine()
                while ($reader.Peek() -ge 0) { $h = $reader.ReadLine(); if ([string]::IsNullOrEmpty($h)) { break } }
                $path = "/"
                if ($reqLine) { $parts = $reqLine -split ' '; if ($parts.Length -ge 2) { $path = $parts[1] } }
                if ($path -like "/data*") { $body = $jsonl; $ctype = "application/json; charset=utf-8" }
                else { $body = $html; $ctype = "text/html; charset=utf-8" }
                $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                $head = "HTTP/1.1 200 OK`r`nContent-Type: $ctype`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($bodyBytes.Length)`r`nConnection: close`r`n`r`n"
                $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
                $stream.Write($headBytes, 0, $headBytes.Length)
                $stream.Write($bodyBytes, 0, $bodyBytes.Length)
                $stream.Flush()
            } finally { $client.Close() }
        }
    } finally { $listener.Stop() }
}
