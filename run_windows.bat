@echo off
rem AGORA, locally on Windows: fetches the GLP repository at the pinned commit
rem (once), lays this repository's files over it, and starts the server on
rem http://localhost:8080.  Needs Git and the Dart SDK on the PATH.
setlocal
set HERE=%~dp0
set GLP=%HERE%glp
set COMMIT=71b98414ec91ad669a790284373c068086754e8d
if not exist "%GLP%\.git" (
  git init "%GLP%" || goto :fail
  git -C "%GLP%" remote add origin https://github.com/EShapiro2/GLP.git
  git -C "%GLP%" fetch --depth 1 origin %COMMIT% || goto :fail
  git -C "%GLP%" checkout FETCH_HEAD || goto :fail
)
xcopy /E /Y /I /Q "%HERE%overlay" "%GLP%" >nul || goto :fail
cd /d "%GLP%\agora_server"
call dart pub get || goto :fail
set GLP_ROOT=%GLP%
set PORT=8080
echo.
echo Starting AGORA (the first start compiles the platform; give it a minute)...
echo Then open http://localhost:8080
call dart run bin\server.dart
goto :eof
:fail
echo Something failed above.
exit /b 1
