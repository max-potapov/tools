@echo off

:: Default installation path
@if "%OPENSSL_PATH%"=="" @set OPENSSL_PATH=C:\OpenSSL-Win32
@if "%1%"=="2008" @set MSVC_VERSION=2008
@if "%2%"=="2008" @set MSVC_VERSION=2008
@if "%MSVC_VERSION%"=="" @set MSVC_VERSION=2010
@set BUILD_TYPE=Debug
@set _=%CD%
@set BUILD_TOOL=nmake
@if "%QT_ROOT%"=="" @set QT_ROOT=%_%/qt

@if "%1%"=="release" @set BUILD_TYPE=Release
@if "%1%"=="Release" @set BUILD_TYPE=Release

@call :setup_jom_buildtool

@call :check_openssl || goto error

@call :print_info


@call :setup_environment_if_need || goto error


:Cleanup
	@rm -rf bin
	@rm -rf build

:Build
	@mkdir build || goto error
	@pushd build || goto error
	@cmake -G"NMake Makefiles" -DQT_QMAKE_EXECUTABLE=%QT_ROOT%/bin/qmake.exe ..  || goto error
	@nmake || goto error
	@nmake package || goto error
	@popd

@echo -- Project sucessfully built!
@exit /B 0

:: --- Helpers

:setup_jom_buildtool
	@call :getcpucorescount
	@echo -- CPUs: %CPU_CORE_COUNT%
	@echo TODO: add jom.exe here
	@exit /B 0


:getcpucorescount
	@call :gettempfilename
	@WMIC CPU Get NumberOfLogicalProcessors /Format:List > %TMPFILE%
	@for /F "tokens=2 delims=\=" %%i in ('type %TMPFILE%') do @set CPU_CORE_COUNT=%%i
	@rm -f %TMPFILE%
	@exit /B 0


:gettempfilename
	@set TMPFILE=%TMP%\mytempfile-%RANDOM%-%RANDOM%.tmp
	@if exist "%TMPFILE%" GOTO :gettempfilename
	@exit /B 0


:check_openssl
	@if not exist %OPENSSL_PATH% (
		@echo OpenSSL Win32 was not found. Please make sure you have it installed or you have OPENSSL_PATH env variable pointing to your custom installation directory
		@echo You can install OpenSSL Win32 by downloading it from http://slproweb.com/download/Win32OpenSSL-1_0_1e.exe
		@exit /B 1
	)
	@exit /B 0


:print_info
	@echo -- Build type is %BUILD_TYPE%
	@echo -- MSVC version: %MSVC_VERSION%
	@exit /B 0

:setup_environment_if_need
	@if not "%ENVIRONMENT_DONE%" == "OK" (
		@echo -- Setting up MSVC environment
		@call :setup_environment
		@set ENVIRONMENT_DONE=OK
	)
	@exit /B 0

:setup_environment
	@if %MSVC_VERSION% == 2008 (
		@call "%VS90COMNTOOLS%\vsvars32.bat"
	) else (
		@call "%VS100COMNTOOLS%\vsvars32.bat"
	)
	@exit /B 0


:error
@cd %_%
@echo -- Project build FAILED
@exit /B 1