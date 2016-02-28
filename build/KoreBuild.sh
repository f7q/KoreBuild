#!/usr/bin/env bash

targets=""
repoFolder=""
while [[ $# > 0 ]]; do
    case $1 in
        -r)
            shift
            repoFolder=$1
            ;;
        *)
            targets+=" $1"
            ;;
    esac
    shift
done
if [ ! -e "$repoFolder" ]; then
    printf "Usage: $filename -r [repoFolder] [ [targets] ]\n\n"
    echo "       -r [repo]     The repository to build"
    echo "       [targets]     A space separated list of targets to run"
    exit 1
fi

echo "Building $repoFolder"
cd $repoFolder

# Make the path relative to the repo root because Sake/Spark doesn't support full paths
koreBuildFolder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
koreBuildFolder="${koreBuildFolder/$repoFolder/}"
koreBuildFolder="${koreBuildFolder#/}"

[ -z "$KOREBUILD_DOTNET_CHANNEL" ] && KOREBUILD_DOTNET_CHANNEL=beta
[ -z "$KOREBUILD_DOTNET_VERSION" ] && KOREBUILD_DOTNET_VERSION=1.0.0.001540

if [ ! -z "$KOREBUILD_SKIP_RUNTIME_INSTALL" ]; then
    echo "Skipping runtime installation because KOREBUILD_SKIP_RUNTIME_INSTALL is set"
else
    # Need to set this variable because by default the install script
    # requires sudo
    export DOTNET_INSTALL_DIR=~/.dotnet
    export PATH=$DOTNET_INSTALL_DIR/bin:$PATH
    export KOREBUILD_FOLDER="$(dirname $koreBuildFolder)"
    chmod +x $koreBuildFolder/dotnet/install.sh
    $koreBuildFolder/dotnet/install.sh --channel $KOREBUILD_DOTNET_CHANNEL --version $KOREBUILD_DOTNET_VERSION
    # ==== Temporary ====
    if ! type dnvm > /dev/null 2>&1; then
        source $koreBuildFolder/dnvm/dnvm.sh
    fi
        if ! type dnx > /dev/null 2>&1 || [ -z "$SKIP_DNX_INSTALL" ]; then
            dnvm install latest -runtime coreclr -alias default
            dnvm install default -runtime mono -alias default
        else
        dnvm use default -runtime mono
    fi
    # ============
fi

# Probe for Mono Reference assemblies
if [ -z "$DOTNET_REFERENCE_ASSEMBLIES_PATH" ]; then
    if [ $(uname) == Darwin ] && [ -d "/Library/Frameworks/Mono.framework/Versions/Current/lib/mono/xbuild-frameworks" ]; then
        export DOTNET_REFERENCE_ASSEMBLIES_PATH="/Library/Frameworks/Mono.framework/Versions/Current/lib/mono/xbuild-frameworks"
    elif [ -d "/usr/local/lib/mono/xbuild-frameworks" ]; then
        export DOTNET_REFERENCE_ASSEMBLIES_PATH="/usr/local/lib/mono/xbuild-frameworks"
    elif [ -d "/usr/lib/mono/xbuild-frameworks" ]; then
        export DOTNET_REFERENCE_ASSEMBLIES_PATH="/usr/lib/mono/xbuild-frameworks"
    fi
fi

if [ "$(uname)" == "Darwin" ]; then
    ulimit -n 2048
fi

echo "Using Reference Assemblies from: $DOTNET_REFERENCE_ASSEMBLIES_PATH"

sakeFolder=$koreBuildFolder/Sake
if [ ! -d $sakeFolder ]; then
    dotnet restore "$koreBuildFolder/project.json" --packages "$koreBuildFolder"
fi

makeFile="makefile.shade"
if [ ! -e $makeFile ]; then
    makeFile="$koreBuildFolder/shade/makefile.shade"
fi

export KOREBUILD_FOLDER="$koreBuildFolder"
mono $sakeFolder/0.2.2/tools/Sake.exe -I $koreBuildFolder/shade -f $makeFile $targets