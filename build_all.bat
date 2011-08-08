@ECHO OFF
ECHO Building build.exe
REM dmd -w -g -debug -D -Ddhtml -w dwin.ddoc build.d -ofbuild.exe
dmd -w -O -inline -noboundscheck -release -D -Ddhtml -w dwin.ddoc build.d -ofbuild.exe
ECHO Cleaning up
del build.obj
ECHO Running build
REM build.exe all debug
build.exe all release
ECHO Testing library
unittest.exe
ECHO Done
