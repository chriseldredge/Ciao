#Ciao

Provides targets for building .NET projects from scratch. Ciao bootstraps the build environment
by fetching the latest version of the NuGet.exe command-line client, restoring NuGet packages
for your solution, injecting version metadata into your assemblies, compiling the solution,
running unit tests and building NuGet packages from your nuspecs. See the project URL
for information on integrating Ciao with your projects.

To install Ciao, run the following command in the Package Manager Console

```
PM> Install-Package Ciao
```

## But Why

Modern CI servers have lots of smarts and can already do most of what Ciao does, so why use Ciao?

For example, AppVeyor knows how to restore your packages, run your unit tests, package your nuspecs and
even push your packages, so what's even the point of this?

Ciao decouples you from a particular CI system so your build scripts work anywhere (even outside of CI
in local development). Leaving the details to someone like AppVeyor or TeamCity makes it harder for you
to migrate from one provider to another and makes it difficult to debug failed builds when you have limited
insight into how these providers collect targets and invoke commands.

A core discipline in the umbrella of Agile processes is to "integrate locally", meaning that before you
commit/push changes, you run the entire build/test/package process locally to make sure you won't break
the build.

Ciao lets you integrate locally and gives you confidence that you'll get a similar result when you push.

## Why not Fake?

[Fake](http://fsharp.github.io/FAKE/) is a cross-platform build tool that also performs automated, integrated
builds. It's pretty cool and you should check it out. Ciao is an alternative that is 100% MSBuild. Ciao gives
you conventions and defaults for common tasks (compiling, running tests, packaging) that you'll have to write
yourself with Fake.

Pick what's right for you!

## Files

When you install Ciao, 3 files are installed next to your `.sln` file: Ciao.proj, Ciao.props, and Ciao.targets.
You should commit these files to version control.

### Ciao.proj (required)

This is the main project your CI should build. This file will be overwritten every time
you open the solution or upgrade to a new version of Ciao. Therefore, never make
changes to this file!

### Ciao.props (required)

This file holds settings for your project that control which features are enabled in Ciao.
See the following sections to learn how to configure your build.

### Ciao.targets (optional)

This file provides a place for you to hook your own targets into the Ciao build lifecycle.
The first time you install Ciao, an example targets file is copied into place with some
samples. If you don't need to hook your own targets, you can delete this file and it will
not be restored when you upgrade to a new version of Ciao.

If you decide you need this file later, you can manually copy the sample from `packages\Ciao.<version>\tools\templates\Ciao.targets`.

## Build Version

Ciao uses 3 properties to build a version string used for injecting assembly attributes and when
running `NuGet.exe pack`:

Property      | Default | Description
--------      | ------- | -----------
VersionPrefix | 1.0.0   | [SemVer](http://semver.org/) compliant version excluding pre-release and build metadata
VersionSuffix |         | A pre-release label such as `alpha` (excluding hyphen)
BuildNumber   | 0       | An integer indicating the build number, generally defined by CI

These properties are combined to define 2 additional properties. Supposing VersionPrefix=2.9.3 and
VersionSuffix=preview and BuildNumber=123:

Property      | Default
--------      | -------
PackageVersion| 2.9.3-preview
PackageVersionWithBuildNumber| 2.9.3-preview-build123

If you would like to let your CI server specify VersionPrefix, remove the property from
your Ciao.props.

See the secion on [Injecting Version Metadata](#injecting-version-metadata) to see how to
set the version on your compiled assemblies using these properties.

## Build Configurations

By default Ciao will compile your solution first in Debug then in Release configuration.
You can override the default by adding an ItemGroup to your Ciao.props:

```xml
<ItemGroup>
  <CiaoBuildConfiguration Include="Release"/>
  <CiaoBuildConfiguration Include="OtherWeirdConfiguration"/>
</ItemGroup>
```

You can also override the target `ResolveCompileConfigurations` to do this dynamically in your
Ciao.targets.

## NuGet

Ciao assumes you are using NuGet Automatic Package Restore. The first thing Ciao does is
fetch NuGet.exe from `https://www.nuget.org/nuget.exe`. You can specify a different URL by
setting the `NuGetClientDownloadUrl` property in your Ciao.props file. You can also prevent
Ciao from downloading the newest NuGet.exe by checking NuGet.exe into your version control
(in `build\tools\NuGet.exe` by default) or specify the `NuGetExePath` property with a path
to NuGet.exe that is already installed on your system. Ciao will see that NuGet.exe is already
present and skip downloading the latest version.

Next, Ciao uses this version of NuGet.exe to restore packages on your solution. This will also
restore the Ciao package at the Solution level.

Finally, the Ciao bootstrapper finds whatever the latest version of Ciao is in the NuGet packages
directory, and invokes MSBuild on `packages\Ciao.<version>\tools\Ciao.proj`. This begins the main
build lifecycle, importing properties and targets and running targets to compile, test and package
your project.

### Packaging with NuGet

Ciao supports building `nupkg`s using the `nuget.exe pack` subcommand. To enable these targets,
set the `NuGetPackEnabled` property to `true` in Ciao.props.

Ciao will look for `.nuspec` files nested anywhere under your top-level Ciao directory. If there
is an adjacent `.csproj` file where a `.nuspec` file is found, Ciao will execute `nuget.exe pack`
on the csproj, otherwise it will execute directly on the nuspec.

You can override which targets are used for `nuget.exe pack` by either overriding the target
`ResolveNuSpecTargets` in your Ciao.targets file, or specifying targets explicitly in your
Ciao.props as in this example:

```xml
<ItemGroup>
  <NuSpecTarget Include="src\MyProject\MyProject.csproj"/>
  <NuSpecTarget Include="src\some\other.nuspec"/>
</ItemGroup>
```

#### Setting Properties and Package Version

By default Ciao will run `NuGet.exe pack` using the last `CiaoBuildConfiguration` (see [Build Configurations](#build-configurations)) and the version as defined in the `PackageVersion`
property.

You can control which build configuration(s), and version(s) are built, and add your own
properties, by either overriding the `ResolveNuGetPackConfigurations` target or adding a `NuGetPackConfiguration` ItemGroup to your Ciao.props file:

```xml
<ItemGroup>
  <NuGetPackConfiguration Include="Prerelease">
    <Version>$(PackageVersionWithBuildNumber)</Version>
    <Properties>Configuration=Debug;PackageVersion=$(PackageVersionWithBuildNumber)</Properties>
  </NuGetPackConfiguration>
  <NuGetPackConfiguration Include="Release">
    <Version>$(PackageVersion)</Version>
    <Properties>Configuration=Release;PackageVersion=$(PackageVersion)</Properties>
  </NuGetPackConfiguration>
</ItemGroup>
```

The above example will run `NuGet.exe pack` on each target with two different configurations.

The first (named Prerelease) will will invoke e.g.

```
NuGet.exe pack foo\bar.nuspec -Properties Configuration=Debug;PackageVersion=1.0.0-build37 -Version 1.0.0-build37
```

The second (named Release) will invoke the pack command again on each target with e.g.

```
NuGet.exe pack foo\bar.nuspec -Properties Configuration=Release;PackageVersion=1.0.0 -Version 1.0.0
```

Using these `NuGetPackConfiguration` items allows you to build your packages in multiple configurations
to allow debug/prerelease and release packages easily.

## Injecting Version Metadata

(TODO)

## Supported CI Systems

### AppVeyor
