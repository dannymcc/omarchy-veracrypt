# VeraCrypt Vaults for Omarchy

Mount and unmount your VeraCrypt containers straight from the Omarchy bar, instead of opening the VeraCrypt GUI and clicking through it every time.

It's an Omarchy Quattro bar-widget plugin with a dropdown panel and a small CLI wrapper. The plugin never stores or handles your passphrases. Mounting hands off to VeraCrypt itself, so VeraCrypt does the credential prompt.

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

## Configure your vaults

Create `~/.config/omarchy/veracrypt-vaults.tsv`, one vault per line:

```text
Personal	/home/danny/vaults/personal.hc	/home/danny/Vaults/Personal
Archive	/home/danny/vaults/archive.tc	/home/danny/Vaults/Archive
```

The columns are tab-separated:

```text
name<TAB>container_path<TAB>mount_directory
```

Blank lines and lines starting with `#` are ignored. There's a `config.example.tsv` in the repo to copy from.

## Use

The plugin appears as a lock icon on the Omarchy bar. Click it to open the dropdown panel. Each configured vault shows:

- mount status
- container path, or mount path once mounted
- `Mount` / `Unmount`
- `Open`, when mounted

You can also drive the wrapper directly:

```bash
scripts/veracrypt-vaults list              # list configured vaults
scripts/veracrypt-vaults status            # mount status for all vaults
scripts/veracrypt-vaults mount Personal
scripts/veracrypt-vaults unmount Personal
scripts/veracrypt-vaults open Personal
```

To prompt for the passphrase in the terminal rather than the VeraCrypt GUI:

```bash
VERACRYPT_VAULTS_TEXT=1 scripts/veracrypt-vaults mount Personal
```

## Dependencies

- Omarchy 4 / Quattro shell
- VeraCrypt CLI on `PATH`
- `findmnt`
- `xdg-open` for the `Open` action

On Arch and Omarchy, VeraCrypt comes from the Arch repositories or the AUR, depending on how your package sources are set up.

## Security notes

Omarchy plugins run unsandboxed inside the long-lived Omarchy shell process. Read this plugin before you enable it.

By design, it does not:

- store VeraCrypt passwords
- pass passphrases on the command line
- add systemd units
- ship privilege-elevation helpers
- install packages for you

Mounting still gives VeraCrypt access to the configured container and mount directory, and a compromised user session can reach anything the user can reach. The plugin narrows the attack surface, it doesn't remove it.

## Validate

On an Omarchy machine:

```bash
omarchy plugin validate .
```

The CLI works without Omarchy, so you can smoke-test it against the example config:

```bash
VERACRYPT_VAULTS_CONFIG=./config.example.tsv scripts/veracrypt-vaults list
```

## Remove

```bash
omarchy plugin disable io.github.dannymcc.veracrypt-vaults
omarchy plugin remove io.github.dannymcc.veracrypt-vaults
```

Delete the config yourself if you're done with it:

```bash
rm ~/.config/omarchy/veracrypt-vaults.tsv
```
