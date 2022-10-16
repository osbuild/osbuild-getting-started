# osbuild-getting-started

The `osbuild-getting-started` project provides some useful tooling for
developers and users of the [osbuild](https://osbuild.org/) ecosystem to run
and develop its projects.

## Executables

### osbuild-crew

The `osbuild-crew` executable provides a way to build RPMs of all projects and
to run instances of all osbuild parts.

#### Examples

Building `osbuild` RPMs from the latest tag and default repository:

```
€ osbuild-crew build rpms osbuild -o .
Starting RPM build(s)
Starting build container build for osbuild@v69
# ...
RPMs created: ['osbuild-69-1.20221014gitfcaad04.fc37.noarch.rpm',
'osbuild-ostree-69-1.20221014gitfcaad04.fc37.noarch.rpm',
'osbuild-tools-69-1.20221014gitfcaad04.fc37.noarch.rpm',
'osbuild-lvm2-69-1.20221014gitfcaad04.fc37.noarch.rpm',
'osbuild-luks2-69-1.20221014gitfcaad04.fc37.noarch.rpm',
'osbuild-selinux-69-1.20221014gitfcaad04.fc37.noarch.rpm',
'python3-osbuild-69-1.20221014gitfcaad04.fc37.noarch.rpm']
Done with RPM build for osbuild@v69
RPMs built succesfully, available in: .
```

Building `osbuild` RPMs from a custom repository and branch:

```
€ osbuild-crew build \
  --osbuild-repo=~/dev/src/work/osbuild \
  --osbuild-ref=module-is-executable \
  rpms osbuild -o .
Starting RPM build(s)
Starting build container build for osbuild@module-is-executable
Setting up build container context in '/tmp/tmpfgjf61nj'.
# ...
RPMs created: ['osbuild-69-1.20221014git91f4c34.fc37.noarch.rpm',
'python3-osbuild-69-1.20221014git91f4c34.fc37.noarch.rpm',
'osbuild-tools-69-1.20221014git91f4c34.fc37.noarch.rpm',
'osbuild-selinux-69-1.20221014git91f4c34.fc37.noarch.rpm',
'osbuild-lvm2-69-1.20221014git91f4c34.fc37.noarch.rpm',
'osbuild-luks2-69-1.20221014git91f4c34.fc37.noarch.rpm',
'osbuild-ostree-69-1.20221014git91f4c34.fc37.noarch.rpm']
Done with RPM build for osbuild@module-is-executable
RPMs built succesfully, available in: .
```

Pretty print an `osbuild` manifest:
```
€ osbuild-crew manifest print manifest.json | head -n20
manifest.json
├── version: 2
└── pipelines (7)
    ├── 0
    │   ├── name: build
    │   ├── runner: org.osbuild.fedora38
    │   └── stages (2)
    │       ├── 0
    │       │   ├── type: org.osbuild.rpm
    │       │   ├── inputs
    │       │   │   └── packages
    │       │   │       ├── type: org.osbuild.files
    │       │   │       ├── origin: org.osbuild.source
    │       │   │       └── references (282)
    │       │   │           ├── 0: alternatives-1.21-1.fc38.x86_64.rpm
    │       │   │           ├── 1: audit-libs-3.0.9-1.fc38.x86_64.rpm
    │       │   │           ├── 2: authselect-1.4.0-3.fc37.x86_64.rpm
    │       │   │           ├── 3: authselect-libs-1.4.0-3.fc37.x86_64.rpm
    │       │   │           ├── 4: basesystem-11-14.fc37.noarch.rpm
    │       │   │           ├── 5: bash-5.2.2-2.fc38.x86_64.rpm
```

`vimdiff` two `osbuild` manifests:
```
€ osbuild-crew manifest diff --skip-stage=org.osbuild.rpm manifest-1.json manifest-2.json | head -n20
# [vimdiff opens]
```
