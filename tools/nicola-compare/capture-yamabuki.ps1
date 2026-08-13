<#
capture-yamabuki.ps1 -- capture real Yamabuki-R behavior (Windows only)

With Yamabuki-R running, type your sentence into this tool's text box. It records
  (1) raw key events (down/up, high-res QueryPerformanceCounter time, injected flag)
  (2) the characters Yamabuki-R actually produced (= its judgment result)
into one timeline and saves JSONL. After capture it serves the data on localhost so
Claude can read and analyze it through the connected Chrome (no copy-paste).

Usage (PowerShell, while Yamabuki-R is active):
  powershell -ExecutionPolicy Bypass -File .\capture-yamabuki.ps1
  -> type into the white window, then close it (or press Esc).
  -> it prints "serving http://localhost:8777/"; tell Claude to read localhost:8777.

Note: ASCII-only source on purpose, so cross-platform transfer never corrupts it.
#>
param(
    [string]$Out = "session.jsonl",
    [switch]$NoServe,
    [int]$Port = 8777
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Low-level keyboard hook + QPC in C#. The callback must not block, so it only appends.
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class KbCapture {
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
    static LowLevelKeyboardProc _proc;        // keep ref so GC does not collect it
    static long _freq;
    public static List<string> Events = new List<string>();
    static readonly object _lock = new object();

    public static double NowUs() {
        long c; QueryPerformanceCounter(out c);
        return (double)c * 1000000.0 / (double)_freq;
    }

    public static void Start() {
        QueryPerformanceFrequency(out _freq);
        _proc = Hook;
        _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0);
    }
    public static void Stop() {
        if (_hook != IntPtr.Zero) { UnhookWindowsHookEx(_hook); _hook = IntPtr.Zero; }
    }

    static IntPtr Hook(int code, IntPtr wParam, IntPtr lParam) {
        if (code >= 0) {
            var k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            int msg = wParam.ToInt32();
            string kind = (msg == 0x100 || msg == 0x104) ? "down" : ((msg == 0x101 || msg == 0x105) ? "up" : "?");
            bool inj = (k.flags & LLKHF_INJECTED) != 0;
            // VK_PACKET(0xE7): KEYEVENTF_UNICODE injection carries the UTF-16 unit in scanCode
            int uni = (k.vkCode == 0xE7) ? (int)k.scanCode : 0;
            double t = NowUs();
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

[KbCapture]::Start()

# Our own window to capture the produced characters.
$form = New-Object System.Windows.Forms.Form
$form.Text = "Yamabuki-R capture -- type here / close or Esc to save"
$form.Width = 720; $form.Height = 420
$form.TopMost = $true

$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true; $tb.Dock = "Fill"
$tb.Font = New-Object System.Drawing.Font("Consolas", 14)
$tb.AcceptsReturn = $true
$form.Controls.Add($tb)

$outEvents = New-Object System.Collections.Generic.List[string]

# Capture the char Yamabuki-R finally delivered (via WM_CHAR)
$tb.Add_KeyPress({
    param($s, $e)
    $t = [KbCapture]::NowUs()
    $ch = [int][char]$e.KeyChar
    $line = '{"t":' + $t.ToString("F1") + ',"src":"out","ch":' + $ch + '}'
    $outEvents.Add($line)
})

$form.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq "Escape") { $form.Close() } })

[void]$form.ShowDialog()

[KbCapture]::Stop()

# Merge and save in timestamp order.
$all = New-Object System.Collections.Generic.List[object]
foreach ($l in [KbCapture]::Events) { $all.Add($l) }
foreach ($l in $outEvents)          { $all.Add($l) }

$sorted = $all | Sort-Object { [double]([regex]::Match($_, '"t":([0-9.]+)').Groups[1].Value) }
Set-Content -Path $Out -Value $sorted -Encoding UTF8

Write-Host "saved $($sorted.Count) events -> $Out"

if (-not $NoServe) {
    # Serve the captured session on localhost so Claude can pull it via the connected Chrome:
    #   http://localhost:$Port/data  -> raw session (JSONL); Claude runs compare.py on it
    #   http://localhost:$Port/      -> simple human view
    # TcpListener (no admin needed) speaking minimal HTTP.
    $jsonl = ($sorted -join "`n")
    $html = @"
<!doctype html><meta charset=utf-8><title>nicola capture</title>
<body style="font-family:Consolas,monospace;padding:20px">
<h3>Yamabuki-R capture: serving</h3>
<p>events: $($sorted.Count). Tell Claude: "read localhost:$Port".</p>
<p>raw data: <a href="/data">/data</a> (Claude pulls this and runs compare.py)</p>
<pre id=p style="max-height:60vh;overflow:auto;background:#f4f5f2;padding:10px"></pre>
<script>fetch('/data').then(function(r){return r.text()}).then(function(t){document.getElementById('p').textContent=t.slice(0,4000)})</script>
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
