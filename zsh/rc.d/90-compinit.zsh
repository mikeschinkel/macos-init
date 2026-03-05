autoload -Uz compinit

# Use a dedicated dump file (keeps $HOME clean and makes it “your” file)
ZSH_COMPDUMP="$HOME/.cache/zsh/zcompdump-${ZSH_VERSION}"
mkdir -p "${ZSH_COMPDUMP:h}"

compinit -d "$ZSH_COMPDUMP"
