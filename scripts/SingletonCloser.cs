using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

public static class SingletonCloser
{
    const uint PROCESS_DUP_HANDLE = 0x0040;
    const uint PROCESS_QUERY_INFORMATION = 0x0400;
    const uint PROCESS_VM_READ = 0x0010;
    const uint TH32CS_SNAPPROCESS = 0x00000002;
    const uint DUPLICATE_CLOSE_SOURCE = 0x00000001;
    const uint DUPLICATE_SAME_ACCESS = 0x00000002;
    const int SystemHandleInformationEx = 64;
    const int ObjectNameInformation = 1;
    const int ObjectTypeInformation = 2;

    [StructLayout(LayoutKind.Sequential)]
    struct SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX
    {
        public IntPtr Object;
        public IntPtr UniqueProcessId;
        public IntPtr HandleValue;
        public uint GrantedAccess;
        public ushort CreatorBackTraceIndex;
        public ushort ObjectTypeIndex;
        public uint HandleAttributes;
        public uint Reserved;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct PROCESSENTRY32W
    {
        public uint dwSize;
        public uint cntUsage;
        public uint th32ProcessID;
        public IntPtr th32DefaultHeapID;
        public uint th32ModuleID;
        public uint cntThreads;
        public uint th32ParentProcessID;
        public int pcPriClassBase;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 260)]
        public char[] szExeFile;
    }

    [DllImport("ntdll.dll")]
    static extern int NtQuerySystemInformation(int infoClass, IntPtr buffer, uint length, out uint returnLength);

    [DllImport("ntdll.dll")]
    static extern int NtQueryObject(IntPtr handle, int infoClass, IntPtr buffer, uint length, out uint returnLength);

    [DllImport("ntdll.dll")]
    static extern int NtDuplicateObject(
        IntPtr sourceProcess, IntPtr sourceHandle, IntPtr targetProcess,
        out IntPtr targetHandle, uint access, uint attributes, uint options);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DuplicateHandle(
        IntPtr sourceProcess, IntPtr sourceHandle, IntPtr targetProcess,
        out IntPtr targetHandle, uint access, bool inherit, uint options);

    [DllImport("kernel32.dll")]
    static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool Process32FirstW(IntPtr snapshot, ref PROCESSENTRY32W entry);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool Process32NextW(IntPtr snapshot, ref PROCESSENTRY32W entry);

    static IntPtr QuerySystemHandles()
    {
        uint size = 0x10000;
        while (true)
        {
            IntPtr buffer = Marshal.AllocHGlobal((int)size);
            uint retLen;
            int status = NtQuerySystemInformation(SystemHandleInformationEx, buffer, size, out retLen);
            if (status == 0)
                return buffer;

            Marshal.FreeHGlobal(buffer);
            if (retLen <= size)
                return IntPtr.Zero;

            size = retLen + 0x1000;
        }
    }

    static IntPtr QueryObjectInfo(IntPtr handle, int infoClass)
    {
        uint size = 0x1000;
        while (true)
        {
            IntPtr buffer = Marshal.AllocHGlobal((int)size);
            uint retLen;
            int status = NtQueryObject(handle, infoClass, buffer, size, out retLen);
            if (status == 0)
                return buffer;

            Marshal.FreeHGlobal(buffer);
            if (retLen <= size)
                return IntPtr.Zero;

            size = retLen + 0x100;
        }
    }

    static int UnicodeStringBufferOffset()
    {
        return IntPtr.Size == 8 ? 8 : 4;
    }

    static string ReadObjectName(IntPtr handle)
    {
        IntPtr buffer = QueryObjectInfo(handle, ObjectNameInformation);
        if (buffer == IntPtr.Zero) return null;

        try
        {
            IntPtr namePtr = Marshal.ReadIntPtr(buffer, UnicodeStringBufferOffset());
            if (namePtr == IntPtr.Zero) return null;
            return Marshal.PtrToStringUni(namePtr);
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    static string ReadObjectType(IntPtr handle)
    {
        IntPtr buffer = QueryObjectInfo(handle, ObjectTypeInformation);
        if (buffer == IntPtr.Zero) return null;

        try
        {
            IntPtr namePtr = Marshal.ReadIntPtr(buffer, UnicodeStringBufferOffset());
            if (namePtr == IntPtr.Zero) return null;
            return Marshal.PtrToStringUni(namePtr);
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    static bool IsRobloxSingleton(string type, string name)
    {
        if (name == null) return false;
        if (!name.EndsWith("ROBLOX_singletonEvent") && !name.EndsWith("ROBLOX_singletonMutex"))
            return false;
        if (type == "Event") return name.EndsWith("ROBLOX_singletonEvent");
        if (type == "Mutant") return name.EndsWith("ROBLOX_singletonMutex");
        return false;
    }

    static List<IntPtr> GetHandlesForPid(uint pid)
    {
        var result = new List<IntPtr>();
        IntPtr buffer = QuerySystemHandles();
        if (buffer == IntPtr.Zero) return result;

        try
        {
            long count = Marshal.ReadInt64(buffer, 0);
            int entrySize = Marshal.SizeOf(typeof(SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX));
            int offset = IntPtr.Size * 2;

            for (long i = 0; i < count; i++)
            {
                var entry = (SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX)Marshal.PtrToStructure(
                    IntPtr.Add(buffer, offset + (int)(i * entrySize)),
                    typeof(SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX));

                if ((uint)entry.UniqueProcessId.ToInt64() == pid)
                    result.Add(entry.HandleValue);
            }
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }

        return result;
    }

    public static int CountRobloxSingletons(uint pid)
    {
        var handles = GetHandlesForPid(pid);
        uint access = PROCESS_DUP_HANDLE | PROCESS_QUERY_INFORMATION | PROCESS_VM_READ;
        IntPtr process = OpenProcess(access, false, pid);
        if (process == IntPtr.Zero) return 0;

        IntPtr current = GetCurrentProcess();
        int found = 0;

        try
        {
            foreach (IntPtr handleValue in handles)
            {
                IntPtr dup;
                if (NtDuplicateObject(process, handleValue, current, out dup, 0, 0, 0) != 0)
                    continue;

                try
                {
                    string type = ReadObjectType(dup);
                    string name = ReadObjectName(dup);
                    if (IsRobloxSingleton(type, name))
                        found++;
                }
                finally
                {
                    CloseHandle(dup);
                }
            }
        }
        finally
        {
            CloseHandle(process);
        }

        return found;
    }

    public static int CloseSingletons(uint pid)
    {
        var handles = GetHandlesForPid(pid);
        uint access = PROCESS_DUP_HANDLE | PROCESS_QUERY_INFORMATION | PROCESS_VM_READ;
        IntPtr process = OpenProcess(access, false, pid);
        if (process == IntPtr.Zero) return 0;

        IntPtr current = GetCurrentProcess();
        int closed = 0;

        try
        {
            foreach (IntPtr handleValue in handles)
            {
                IntPtr dup;
                if (NtDuplicateObject(process, handleValue, current, out dup, 0, 0, 0) != 0)
                    continue;

                try
                {
                    string type = ReadObjectType(dup);
                    string name = ReadObjectName(dup);
                    if (!IsRobloxSingleton(type, name))
                        continue;

                    IntPtr ignored;
                    if (DuplicateHandle(process, handleValue, IntPtr.Zero, out ignored, 0, false,
                        DUPLICATE_CLOSE_SOURCE | DUPLICATE_SAME_ACCESS))
                    {
                        closed++;
                    }
                }
                finally
                {
                    CloseHandle(dup);
                }
            }
        }
        finally
        {
            CloseHandle(process);
        }

        return closed;
    }

    public static List<uint> FindRobloxPids()
    {
        var pids = new List<uint>();
        IntPtr snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snapshot == IntPtr.Zero || snapshot == new IntPtr(-1))
            return pids;

        try
        {
            var entry = new PROCESSENTRY32W { dwSize = (uint)Marshal.SizeOf(typeof(PROCESSENTRY32W)) };
            if (!Process32FirstW(snapshot, ref entry))
                return pids;

            do
            {
                string name = new string(entry.szExeFile).Split('\0')[0];
                if (name.Equals("RobloxPlayerBeta.exe", StringComparison.OrdinalIgnoreCase))
                    pids.Add(entry.th32ProcessID);
            }
            while (Process32NextW(snapshot, ref entry));
        }
        finally
        {
            CloseHandle(snapshot);
        }

        return pids;
    }

    public static int CloseAllRobloxSingletons()
    {
        int total = 0;
        foreach (uint pid in FindRobloxPids())
            total += CloseSingletons(pid);
        return total;
    }

    public static uint WaitForNewRobloxProcess(List<uint> existing, int timeoutMs)
    {
        DateTime deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while (DateTime.UtcNow < deadline)
        {
            foreach (uint pid in FindRobloxPids())
            {
                if (!existing.Contains(pid))
                    return pid;
            }
            Thread.Sleep(200);
        }
        return 0;
    }

    public static int CloseAllRobloxSingletonsRepeated(int attempts, int delayMs)
    {
        int total = 0;
        for (int i = 0; i < attempts; i++)
        {
            total += CloseAllRobloxSingletons();
            if (i + 1 < attempts)
                Thread.Sleep(delayMs);
        }
        return total;
    }
}
