/++
Build tool for dwin

License: $(BOOST)
Authors: $(SIMENDSJO)
Source: $(MODULE_SOURCE_LINK)
++/
module build;

import std.stdio, std.getopt, std.path, std.process, std.file, std.format, std.array,
       std.algorithm, std.exception;

string buildFlags;
string dwinPath;

immutable defaultFlags  = " -w -version=Unicode -version=WindowsVista ";
immutable releaseFlags  = " -O -inline -release -noboundscheck ";
immutable debugFlags    = " -g -debug -debug=dwin -unittest ";

private bool libExists(string lib) {
    auto filename = std.path.join(dwinPath, "lib", lib~".lib");
    debug writeln("Checking for '", filename, "'");
    return exists(filename);
}

private string[] getLibSourceFiles(string lib) {
    auto srcPath = std.path.join(dwinPath, "src", lib);
    debug writeln("Get ", lib, " D files from ", srcPath);
    enforce(exists(srcPath), "Cannot find " ~ lib ~ " source at " ~ srcPath);
    auto entries = dirEntries(srcPath, SpanMode.breadth);
    auto filenames = map!`a.name`(entries);
    return array(filter!`endsWith(a, ".d") || endsWith(a, ".di")`(filenames));
}

private void doBuildWin32() {
    auto srcPath = std.path.join(dwinPath, "src", "win32");
    debug writeln("Building win32 ", srcPath);
    auto dfiles = getLibSourceFiles("win32");
    auto win32files = array(filter!`std.path.basename(a) != "uuid.di" && std.path.basename(a) != "winsock.d"`(dfiles));
    buildLib("win32", win32files, "-I"~dwinPath~r"\src");
}

private void buildLib(string name, string[] files, string extraFlags="") {
    auto dmdParamWriter = appender!string();
    formattedWrite(dmdParamWriter, r"%1$s\dwin.ddoc -I%1$s\import -D -Dd%1$s\html\%2$s -H -Hd%1$s\import\%2$s -lib -of%1$s\lib\%2$s.lib %3$s %4$s %5$s ", dwinPath, name, buildFlags, extraFlags, joiner(files, " "));
    //debug writeln(dmdParamWriter.data);
    auto dmdParamFile = std.path.join(dwinPath, name~"_dmd_params.build");
    debug writeln("Writing dmd params to "~dmdParamFile);
    std.file.write(dmdParamFile, dmdParamWriter.data);
    debug {
    }
    else {
        scope(exit) remove(dmdParamFile);
    }
    debug writeln("dmd @"~dmdParamFile);
    enforce(system("dmd @"~dmdParamFile) == 0);
}

private void doBuildDWin() {
    !libExists("win32") && doBuildWin32();
    debug writeln("Building dwin");
    auto dfiles = getLibSourceFiles("dwin");
    buildLib("dwin", dfiles, std.path.join(dwinPath, "lib", "win32.lib"));

    auto docWriter = appender!string();
    formattedWrite(docWriter, r"dmd %1$s\dwin.ddoc -D -Dd%1$s\html %1$s\index.dd %1$s\changelog.dd", dwinPath);
    enforce(system(docWriter.data) == 0);
}

private void doBuildSamples() {
    !libExists("dwin") && doBuildDWin();
    debug writeln("Building samples");
}

private void doBuildTest() {
    !libExists("dwin") && doBuildDWin();
    debug writeln("Building test program");
    auto dwinFiles = getLibSourceFiles("dwin");
    auto dmdOptions = appender!string();
    formattedWrite(dmdOptions, r"-w -g -unittest -version=Unicode -version=WindowsVista -of%1$s\unittest.exe %1$s\unittest.d %2$s", dwinPath, joiner(dwinFiles, " "));
    std.file.write("unittest.dmdoptions", dmdOptions.data);
    scope(exit) std.file.remove("unittest.dmdoptions");
    enforce(system(std.string.format(r"dmd @%s\unittest.dmdoptions", dwinPath)) == 0);
    scope(exit) std.file.remove("unittest.obj");
}

void printHelp() {
    writeln("win32   = Build win32");
    writeln("dwin    = Build dwin");
    writeln("samples = Build dwin samples");
    writeln("test    = Build dwin test libraries and executable");
    writeln("all     = Build all of the above");
    writeln("All other values are sent to dmd");
    writeln();
    writeln("release = shortcut for adding '", releaseFlags, "'");
    writeln("debug   = shortcut for adding '", debugFlags, "'");
    writeln("noflags = Don't add any flags at all");
    writeln("Always added if not using 'noflags', '", defaultFlags, "'");
    writeln();
    writeln("Example: build.exe dwin samples\n\tBuilds dwin and samples");
}

int main(string[] args) {
    if(args.length == 1) {
        printHelp();
        return 1;
    }

    dwinPath = rel2abs(dirname(args[0]));
    debug writeln("DWin path: ", dwinPath);

    bool buildDwin;
    bool buildWin32;
    bool buildSamples;
    bool buildTest;

    bool flagsRelease;
    bool flagsDebug;
    bool noFlags;

    string[] dmdOptions;

    foreach(arg; args[1..$]) {
        switch(arg) {
            case "win32":
                buildWin32      = true;
                break;
            case "dwin":
                buildDwin       = true;
                break;
            case "samples":
                buildSamples    = true;
                break;
            case "test":
                buildTest       = true;
                break;
            case "all":
                buildWin32      = true;
                buildDwin       = true;
                buildSamples    = true;
                buildTest       = true;
                break;
            case "release":
                flagsRelease    = true;
                break;
            case "debug":
                flagsDebug      = true;
                break;
            case "noflags":
                noFlags         = true;
                break;
            case "help", "-h", "--help", "/?":
                printHelp();
                return 1;
            default: // DMD option
                if(arg[0] != '-')
                    throw new Exception("Unknown argument '"~arg~"'");
                dmdOptions ~= arg;
        }
    }

    debug writeln("DMD options: ", dmdOptions);

    if(flagsRelease + flagsDebug + noFlags > 1)
        throw new Exception("Cannot combine flag options");

    if(!noFlags)
        buildFlags = defaultFlags;
    if(flagsRelease)
        buildFlags ~= releaseFlags;
    else if(flagsDebug)
        buildFlags ~= debugFlags;

    buildWin32      && doBuildWin32();
    buildDwin       && doBuildDWin();
    buildSamples    && doBuildSamples();
    buildTest       && doBuildTest();

    return 0;
}
