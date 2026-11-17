#include "../include/exam_session.h"
#include <string>
#include <windows.h>

EXPORT int32_t initialize_lockdown() {
#ifdef _WIN32
    // 1. Save the original desktop
    HDESK hOriginalDesktop = GetThreadDesktop(GetCurrentThreadId());

    // 2. Create the secure desktop
    HDESK hSecureDesktop = CreateDesktopA("ExamSecureDesktop", NULL, NULL, 0, GENERIC_ALL, NULL);
    if (hSecureDesktop == NULL) {
        return 0;
    }

    // 3. Get the path to the currently running executable
    char exePath[MAX_PATH];
    GetModuleFileNameA(NULL, exePath, MAX_PATH);

    // Pass a flag so the new instance knows it is in the secure environment
    std::string cmdLine = std::string(exePath) + " --secure";

    // 4. Configure the startup info to target the new desktop
    STARTUPINFOA si = {sizeof(si)};
    si.lpDesktop = (LPSTR) "ExamSecureDesktop";
    PROCESS_INFORMATION pi;

    // 5. Launch the application clone
    if (CreateProcessA(exePath, (LPSTR)cmdLine.c_str(), NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        
        // Switch the monitor to the secure desktop
        SwitchDesktop(hSecureDesktop);

        // Pause this original process until the secure app is closed by the user
        WaitForSingleObject(pi.hProcess, INFINITE);

        // Once the secure app closes, switch the monitor back to normal
        SwitchDesktop(hOriginalDesktop);

        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }

    CloseDesktop(hSecureDesktop);
    return 1;
#else
    return -1;
#endif
}