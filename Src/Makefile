# Required macros
# ---------------
#
# Make will fail if any of the following macros are not defined externally to
# this makefile.
#
# DELPHIROOT (or DELPHI2010)
#   DELPHIROOT must address the installation directory of the required Delphi
#   compiler: Delphi 2010 is preferred and compilation with earlier versions may
#   fail without source code changes. If Delphi 2010 is to be used the
#   DELPHI2010 macro can be defined to address the Delphi 2010 installation
#   directory. When DELPHI2010 is defined any existing value of DELPHIROOT is
#   ignored and DELPHI2010 is used instead.
#
# Optional macros
# ---------------
#
# The following macros are optional but may be provided to vary defaults used
# within this makefile.
#
# VIEDROOT
#   Install path of Version Information Editor (VIEd) used to process version
#   information (.vi) files. If not set VIEd must be on the system path.
#
# ZIPROOT
#   Install path of ZIP.exe used to create the release zip file. If not present
#   ZIP.exe must be on the system path.
#
# RELEASEFILENAME
#   Specifies the name, without path or extension, of the zip file used to
#   contain the YaLife program when released. If not set then the default name
#   hard wired into this file is used.


# Set bin output path
BIN = ..\Bin

!ifdef DELPHI2010
DELPHIROOT = $(DELPHI2010)
!endif

# Check for required macros
!ifndef DELPHIROOT
!error DELPHIROOT or DELPHI2010 environment variable required.
!endif

# Define common macros that access required build tools
MAKE = "$(MAKEDIR)\Make.exe" -$(MAKEFLAGS)
DCC32 = "$(DELPHIROOT)\Bin\DCC32.exe"
BRCC32 = "$(DELPHIROOT)\Bin\BRCC32.exe"
!ifdef VIEDROOT
VIED = "$(VIEDROOT)\VIEd.exe" -makerc
!else
VIED = VIEd.exe -makerc
!endif
!ifdef ZIPROOT
ZIP = "$(ZIPROOT)\Zip.exe"
!else
ZIP = Zip.exe
!endif

# Implicit rules
# Delphi projects are assumed to contain required output and search path
# locations in the project options .cfg file.
.dpr.exe:
  @echo +++ Compiling Delphi Project $< +++
  @$(DCC32) $< -B -U"$(DELPHIDABLIB)"

# Resource files are compiled to the directory specified by the BIN macro.
.rc.res:
  @echo +++ Compiling Resource file $< +++
  @$(BRCC32) $< -fo$(BIN)\$(@F)

# Version info files are compiled by VIEd. A temporary .rc file is left behind
.vi.rc:
  @echo +++ Compiling Version Info file $< +++
  @$(VIED) .\$<

# Default target is to configure and build everything
everything: config resources pascal

# Make executable program from source
exe: resources pascal

# Configure source folders
config:
  @echo Configuring
  # Create build folders
  @cd ..
  @if exist Bin rmdir /S /Q Bin
  @if exist Exe rmdir /S /Q Exe
  @if exist Release rmdir /S /Q Release
  @mkdir Bin
  @mkdir Exe
  @mkdir Release
  @cd Src

# Compiles the resources and deletes intermediate file created by VIED
resources: Version.res Resources.res
  -@del Version.rc

# Builds Pascal files and links program
pascal: YaLife.exe

# Build release files (.zip)
!ifndef RELEASEFILENAME
RELEASEFILENAME = dd-yalife-exe
!endif
OUTFILE = Release\$(RELEASEFILENAME).zip
release:
  @echo.
  @echo Creating Release File
  @echo ---------------------
  @cd ..
  -@if exist $(OUTFILE) del $(OUTFILE)
  @$(ZIP) -j -9 $(OUTFILE) Exe\YaLife.exe
  @cd Src

# Clean up unwanted files
clean:
  @cd ..
  # remove unwanted files: temps (~ or .~*), .dsk, .local, .identcache
  -@del /S *.~* 2>nul
  -@del /S ~* 2>nul
  -@del /S *.dsk 2>nul
  -@del /S *.local 2>nul
  -@del /S *.identcache 2>nul
  # remove __history folders
  -@for /F "usebackq" %i in (`dir /S /B /A:D ..\__history`) do @rmdir /S /Q %i
  @cd Src
