Identify shell version first.
Following versions are supported:
- `bash`
- `zsh`

Identify system installer next.
Commonly, it should be one of the following:
- `apt-get`
- `yum`

Get `miniconda` from [offical website](https://docs.conda.io/en/latest/miniconda.html).

Manually add following commands to shell runtime command.
```bash
export CONDA=...
. ${HOME}/Workplace/RuntimeCommand/.shrc
```