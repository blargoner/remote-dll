;
; Remote Library Loader
; Developed by John Peloquin
;
; Creation Environment: Microsoft Assembler
; Run-time Environment: Microsoft Windows NT/2000/XP
;
;--------------------------------------------------------------------------------

;
; Assembler directives
;--------------------------------------------------------------------------------

.386
.model flat,stdcall
option casemap:none

;
; Included
;--------------------------------------------------------------------------------

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib

;
; Function prototypes
;--------------------------------------------------------------------------------

LoaderError proto :HWND,:LPSTR
WinMain proto :HINSTANCE,:HINSTANCE,:LPSTR,:DWORD

;
; Data
;--------------------------------------------------------------------------------

.data

nPlugin dd 11							; Plugin name size
strTarget db "Target.exe",0					; Target name
strPlugin db "Plugin.dll",0					; Plugin name

strRemoteLib db "Kernel32",0					; Library name
strRemoteFunc db "LoadLibraryA",0				; Function name

strErrorTitle db "Remote Loader Error",0			; Error title
strError1 db "Unable to create target process!",0		; Errors
strError2 db "Unable to allocate memory in target process!",0
strError3 db "Unable to write to memory in target process!",0
strError4 db "Unable to create thread in target process!",0
strError5 db "Unable to load plugin DLL in target process!",0

;
; Code
;--------------------------------------------------------------------------------

.code

start:

	; Startup code
	invoke GetModuleHandle,NULL
	invoke WinMain,eax,NULL,NULL,SW_SHOWDEFAULT
	invoke ExitProcess,eax

	;
	; Error handler
	;--------------------------------------------------------------------------------

	LoaderError proc hWndParent:HWND,strError:LPSTR

		; Show error message to user
		invoke MessageBox,hWndParent,strError,addr strErrorTitle,MB_OK or MB_ICONERROR

		; Return
		xor eax,eax
		ret

	LoaderError endp

	;
	; Entry point
	;--------------------------------------------------------------------------------

	WinMain proc hInstance:HINSTANCE,hPrevInstance:HINSTANCE,strCmdLine:LPSTR,nShowCmd:DWORD

		; Local variables
		LOCAL nRemote:DWORD				; Remote thread ID
		LOCAL hRemote:HANDLE				; Remote thread handle
		LOCAL pLoadLibrary:LPVOID			; LoadLibrary function pointer
		LOCAL strRemotePlugin:LPSTR			; Remote plugin filename buffer
		LOCAL hTargetInit:STARTUPINFO			; Process startup structure
		LOCAL hTargetInfo:PROCESS_INFORMATION		; Process information structure

		; Zero startup structure
		cld

		xor eax,eax
		mov ecx,sizeof STARTUPINFO
		lea edi,hTargetInit

		push ecx
		shr ecx,2
		rep stosd

		pop ecx
		and ecx,3
		rep stosb

		; Set startup structure size
		mov hTargetInit.cb,sizeof STARTUPINFO

		; Create target process
		invoke CreateProcess,\
						addr strTarget,\		; Application name
						NULL,\				; Command line
						NULL,\				; Process security
						NULL,\				; Thread security
						FALSE,\				; Inherit handles
						0,\				; Creation flags
						NULL,\				; Environment
						NULL,\				; Directory
						addr hTargetInit,\		; Startup structure
						addr hTargetInfo		; Information structure

		; Check for failure
		.if(!eax)

			; Call error handler and return
			invoke LoaderError,NULL,addr strError1
			ret

		.endif

		; Close unneeded handle
		invoke CloseHandle,hTargetInfo.hThread

		; Allocate buffer in target process address space
		invoke VirtualAllocEx,hTargetInfo.hProcess,NULL,nPlugin,MEM_COMMIT,PAGE_READWRITE
		mov strRemotePlugin,eax

		; Check for failure
		.if(!eax)

			; Call error handler and return
			invoke CloseHandle,hTargetInfo.hProcess
			invoke LoaderError,NULL,addr strError2
			ret

		.endif

		; Copy plugin library filename into remote buffer
		invoke WriteProcessMemory,hTargetInfo.hProcess,strRemotePlugin,addr strPlugin,nPlugin,NULL

		.if(!eax)

			; Free resources
			invoke VirtualFreeEx,hTargetInfo.hProcess,strRemotePlugin,0,MEM_RELEASE
			invoke CloseHandle,hTargetInfo.hProcess

			; Call error handler and return
			invoke LoaderError,NULL,addr strError3
			ret

		.endif

		; Get address of LoadLibrary function
		invoke GetModuleHandle,addr strRemoteLib
		invoke GetProcAddress,eax,addr strRemoteFunc
		mov pLoadLibrary,eax

		; Create remote thread to call LoadLibrary
		invoke CreateRemoteThread,\
						hTargetInfo.hProcess,\		; Process
						NULL,\				; Security
						0,\				; Stack size
						pLoadLibrary,\			; Function
						strRemotePlugin,\		; Parameter
						0,\				; Creation flags
						NULL				; Thread ID

		mov hRemote,eax

		; Check for failure
		.if(!eax)

			; Free resources
			invoke VirtualFreeEx,hTargetInfo.hProcess,strRemotePlugin,0,MEM_RELEASE
			invoke CloseHandle,hTargetInfo.hProcess

			; Call error handler and return
			invoke LoaderError,NULL,addr strError4
			ret

		.endif

		; Wait for remote thread to finish
		invoke WaitForSingleObject,eax,INFINITE
		invoke GetExitCodeThread,hRemote,addr nRemote
		invoke CloseHandle,hRemote

		; Check for LoadLibrary failure
		.if(!nRemote)

			; Call error handler
			invoke LoaderError,NULL,addr strError5

		.endif

		; Free resources
		invoke VirtualFreeEx,hTargetInfo.hProcess,strRemotePlugin,0,MEM_RELEASE
		invoke CloseHandle,hTargetInfo.hProcess

		; Return
		xor eax,eax
		ret

	WinMain endp

end start
