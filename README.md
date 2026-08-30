# VeraCrypt Vaults for Omarchy

Mount and unmount configured VeraCrypt containers from the Omarchy bar.

This is an Omarchy Quattro shell plugin with a small CLI wrapper. The plugin does
not store VeraCrypt passphrases. Mounting delegates to VeraCrypt itself, so the
VeraCrypt GUI handles credential prompts.

## Install

```bash
omarchy plugin add https://github.com/dannymcc/omarchy-veracrypt.git --enable
```

For local development:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r "$PWD" ~/.config/omarchy/plugins/io.github.dannymcc.veracrypt-vaults
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.dannymcc.veracrypt-vaults
```

## Configure Vaults

Create `~/.config/omarchy/veracrypt-vaults.tsv`:

```text
Personal	/home/danny/vaults/personal.hc	/home/danny/Vaults/Personal
Archive	/home/danny/vaults/archive.tc	/home/danny/Vaults/Archive
```

The file is tab-separated:

```text
name<TAB>container_path<TAB>mount_directory
```

Blank lines and lines beginning with `#` are ignored.

## Use

Click the VeraCrypt bar widget to open the panel. Each configured vault shows:

- mount status
- container path or mount path
- `Mount` / `Unmount`
- `Open` when mounted

The wrapper can also be used directly:

```bash
scripts/veracrypt-vaults status
scripts/veracrypt-vaults mount Personal
scripts/veracrypt-vaults unmount Personal
scripts/veracrypt-vaults open Personal
```

For terminal-only passphrase prompting:

```bash
VERACRYPT_VAULTS_TEXT=1 scripts/veracrypt-vaults mount Personal
```

## Dependencies

- Omarchy 4 / Quattro shell
- VeraCrypt CLI on `PATH`
- `findmnt`
- `xdg-open` for the `Open` action

On Arch/Omarchy, VeraCrypt is commonly installed from the Arch repositories or
AUR depending on your configured package sources.

## Security Notes

Omarchy plugins run unsandboxed inside the long-lived Omarchy shell process.
Review this plugin before enabling it.

This plugin deliberately avoids:

- storing VeraCrypt passwords
- passing passphrases on the command line
- adding systemd units
- privilege elevation helpers
- installing packages automatically

Mounting still gives VeraCrypt access to the configured container and mount
directory. A compromised user session can access anything the user can access.

## Validate

On an Omarchy machine:

```bash
omarchy plugin validate .
```

The CLI can be checked without Omarchy:

```bash
VERACRYPT_VAULTS_CONFIG=./config.example.tsv scripts/veracrypt-vaults list
```

## Remove

```bash
omarchy plugin disable io.github.dannymcc.veracrypt-vaults
omarchy plugin remove io.github.dannymcc.veracrypt-vaults
```

Remove the config file manually if you no longer want it:

```bash
rm ~/.config/omarchy/veracrypt-vaults.tsv
```
