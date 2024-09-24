# dotfiles
Dotfiles, managed with chezmoi


## Set up a new machine

Install the dotfiles on new machine with:

```$ chezmoi init --apply https://github.com/$GITHUB_USERNAME/dotfiles.git```

This can be shortened to: (public Github repos only)

```$ chezmoi init --apply $GITHUB_USERNAME```

Private GitHub repos require other authentication methods:

```chezmoi init --apply git@github.com:$GITHUB_USERNAME/dotfiles.git```
