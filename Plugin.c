//
// Sample Plugin
// Developed by John Peloquin
//
//--------------------------------------------------------------------------------

//
// Included headers
//--------------------------------------------------------------------------------

#include <windows.h>

//
// Plugin procedure
//--------------------------------------------------------------------------------

DWORD WINAPI PluginProc(LPVOID pData)
{
	// Show message box to user
	MessageBox(NULL, "Valuable code would execute here!", "Success", MB_OK | MB_ICONASTERISK);
	return 0;
}

//
// Entry point
//--------------------------------------------------------------------------------

BOOL WINAPI DllMain(HINSTANCE hInstance, DWORD nReason, LPVOID pReserved)
{
	// Local variables
	DWORD nThread;			// Thread value
	HANDLE hThread;			// Thread handle

	// Check for process attach
	if(nReason == DLL_PROCESS_ATTACH)
	{
		// Attempt to create new thread
		if((hThread = CreateThread(
						NULL,			// Security
						0,			// Stack size
						PluginProc,		// Function
						NULL,			// Parameter
						0,			// Disposition
						&nThread		// Value

					  )) != NULL)
		{
			// Close handle
			CloseHandle(hThread);
		}
	}

	// Return success
	return TRUE;
}

//--------------------------------------------------------------------------------
