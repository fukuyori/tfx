# カラーテーマ設定サンプル

このドキュメントは、`~/Library/Application Support/tfx/config.toml` に貼り付けて使える `[colors]` サンプル集です。

oh-my-posh や Vim / Neovim の定番カラーテーマの雰囲気を参考にしていますが、既存テーマの正確な移植ではありません。tfx のファイル一覧、フォルダツリー、ペイン境界、ステータス行で読みやすいように調整した独自サンプルです。

使い方:

```toml
version = 1

[colors]
# ここに好きなサンプルの [colors] 以下をコピーします
```

各サンプルは主要な色トークンだけを指定しています。指定していない色は tfx の既定色が使われます。すべての色キーの説明は [`configuration.ja.md`](configuration.ja.md) を参照してください。

## クラシカル / 端末風

### 1. Classic Green Phosphor

```toml
[colors]
fileListBackground = "#000301"
fileListRowSelected = "#102E1A"
fileListRowDropTarget = "#125625"
fileForeground = "#CFFFCF"
directoryForeground = "#6FFF80"
secondaryForeground = "#1A8F39"
headerForeground = "#6FFF80"
headerBackground = "#030905"
titleBarBackgroundActive = "#102E1A"
titleBarBackgroundInactive = "#030905"
statusLineForegroundActive = "#6FFF80"
statusLineForegroundInactive = "#1A8F39"
statusLineBackground = "#030905"
paneBorderKeyboardTarget = "#6FFF80"
paneBorderActive = "#1A8F39"
paneBorderInactive = "#125625"
folderTreeBackground = "#000301"
folderTreeForeground = "#CFFFCF"
folderTreeSelectedForeground = "#6FFF80"
folderTreeFolderIcon = "#2DD956"
folderTreeSelectedActive = "#102E1A"
folderTreeSelectedInactive = "#061109"
folderTreeSectionHeader = "#6FFF80"
splitHandleIdle = "#125625"
splitHandleActive = "#6FFF80"
```

### 2. Amber VT

```toml
[colors]
fileListBackground = "#120800"
fileListRowSelected = "#3A2406"
fileListRowDropTarget = "#6B3A08"
fileForeground = "#FFE7B0"
directoryForeground = "#FFB84D"
secondaryForeground = "#B87928"
headerForeground = "#FFD36A"
headerBackground = "#1C0D00"
titleBarBackgroundActive = "#4A2A08"
titleBarBackgroundInactive = "#1C0D00"
statusLineForegroundActive = "#FFD36A"
statusLineForegroundInactive = "#B87928"
statusLineBackground = "#1C0D00"
paneBorderKeyboardTarget = "#FFD36A"
paneBorderActive = "#B87928"
paneBorderInactive = "#5A3510"
folderTreeBackground = "#120800"
folderTreeForeground = "#FFE7B0"
folderTreeSelectedForeground = "#FFF0C8"
folderTreeFolderIcon = "#FFB84D"
folderTreeSelectedActive = "#4A2A08"
folderTreeSelectedInactive = "#2A1805"
folderTreeSectionHeader = "#FFD36A"
splitHandleIdle = "#5A3510"
splitHandleActive = "#FFD36A"
```

### 3. Blue CRT

```toml
[colors]
fileListBackground = "#010711"
fileListRowSelected = "#06264A"
fileListRowDropTarget = "#0B4C78"
fileForeground = "#D8EEFF"
directoryForeground = "#67B7FF"
secondaryForeground = "#4D7EA8"
headerForeground = "#94D2FF"
headerBackground = "#03111F"
titleBarBackgroundActive = "#08345F"
titleBarBackgroundInactive = "#03111F"
statusLineForegroundActive = "#94D2FF"
statusLineForegroundInactive = "#4D7EA8"
statusLineBackground = "#03111F"
paneBorderKeyboardTarget = "#94D2FF"
paneBorderActive = "#4D7EA8"
paneBorderInactive = "#1C4B70"
folderTreeBackground = "#010711"
folderTreeForeground = "#D8EEFF"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#67B7FF"
folderTreeSelectedActive = "#08345F"
folderTreeSelectedInactive = "#041E38"
folderTreeSectionHeader = "#94D2FF"
splitHandleIdle = "#1C4B70"
splitHandleActive = "#94D2FF"
```

### 4. Paperwhite Mono

```toml
[colors]
fileListBackground = "#F5F1E8"
fileListRowSelected = "#DED6C7"
fileListRowDropTarget = "#CFC1A9"
fileForeground = "#241F1A"
directoryForeground = "#5A3E20"
secondaryForeground = "#766A5B"
headerForeground = "#4A3320"
headerBackground = "#E7DFD2"
titleBarBackgroundActive = "#D7CBB9"
titleBarBackgroundInactive = "#E7DFD2"
statusLineForegroundActive = "#4A3320"
statusLineForegroundInactive = "#766A5B"
statusLineBackground = "#E7DFD2"
paneBorderKeyboardTarget = "#6B4725"
paneBorderActive = "#9A7D5D"
paneBorderInactive = "#C9BDAD"
folderTreeBackground = "#F0EADF"
folderTreeForeground = "#241F1A"
folderTreeSelectedForeground = "#1A130E"
folderTreeFolderIcon = "#6B4725"
folderTreeSelectedActive = "#D7CBB9"
folderTreeSelectedInactive = "#E2D9CA"
folderTreeSectionHeader = "#4A3320"
splitHandleIdle = "#C9BDAD"
splitHandleActive = "#6B4725"
```

### 5. DOS Midnight

```toml
[colors]
fileListBackground = "#000018"
fileListRowSelected = "#001A58"
fileListRowDropTarget = "#003C8C"
fileForeground = "#D7D7FF"
directoryForeground = "#00FFFF"
secondaryForeground = "#7A7AC8"
headerForeground = "#FFFF55"
headerBackground = "#000038"
titleBarBackgroundActive = "#002070"
titleBarBackgroundInactive = "#000038"
statusLineForegroundActive = "#FFFF55"
statusLineForegroundInactive = "#7A7AC8"
statusLineBackground = "#000038"
paneBorderKeyboardTarget = "#FFFF55"
paneBorderActive = "#00AEEF"
paneBorderInactive = "#003C8C"
folderTreeBackground = "#000018"
folderTreeForeground = "#D7D7FF"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#00FFFF"
folderTreeSelectedActive = "#002070"
folderTreeSelectedInactive = "#001248"
folderTreeSectionHeader = "#FFFF55"
splitHandleIdle = "#003C8C"
splitHandleActive = "#FFFF55"
```

### 6. Sepia Console

```toml
[colors]
fileListBackground = "#160F09"
fileListRowSelected = "#3A2918"
fileListRowDropTarget = "#6A4826"
fileForeground = "#EAD8B7"
directoryForeground = "#D99A4E"
secondaryForeground = "#9B7650"
headerForeground = "#F0C36A"
headerBackground = "#21150D"
titleBarBackgroundActive = "#4A321D"
titleBarBackgroundInactive = "#21150D"
statusLineForegroundActive = "#F0C36A"
statusLineForegroundInactive = "#9B7650"
statusLineBackground = "#21150D"
paneBorderKeyboardTarget = "#F0C36A"
paneBorderActive = "#9B7650"
paneBorderInactive = "#5A3B22"
folderTreeBackground = "#160F09"
folderTreeForeground = "#EAD8B7"
folderTreeSelectedForeground = "#FFF0D0"
folderTreeFolderIcon = "#D99A4E"
folderTreeSelectedActive = "#4A321D"
folderTreeSelectedInactive = "#2B1C10"
folderTreeSectionHeader = "#F0C36A"
splitHandleIdle = "#5A3B22"
splitHandleActive = "#F0C36A"
```

### 7. Black Ice Terminal

```toml
[colors]
fileListBackground = "#020407"
fileListRowSelected = "#101A22"
fileListRowDropTarget = "#183A4A"
fileForeground = "#DCE8EE"
directoryForeground = "#9BE7FF"
secondaryForeground = "#6F8791"
headerForeground = "#B9F1FF"
headerBackground = "#070B10"
titleBarBackgroundActive = "#152530"
titleBarBackgroundInactive = "#070B10"
statusLineForegroundActive = "#B9F1FF"
statusLineForegroundInactive = "#6F8791"
statusLineBackground = "#070B10"
paneBorderKeyboardTarget = "#B9F1FF"
paneBorderActive = "#6F8791"
paneBorderInactive = "#28414C"
folderTreeBackground = "#020407"
folderTreeForeground = "#DCE8EE"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#9BE7FF"
folderTreeSelectedActive = "#152530"
folderTreeSelectedInactive = "#0C151C"
folderTreeSectionHeader = "#B9F1FF"
splitHandleIdle = "#28414C"
splitHandleActive = "#B9F1FF"
```

### 8. Red Operator

```toml
[colors]
fileListBackground = "#0B0304"
fileListRowSelected = "#2A0C12"
fileListRowDropTarget = "#5A1520"
fileForeground = "#F4D7D9"
directoryForeground = "#FF6B7A"
secondaryForeground = "#9E5962"
headerForeground = "#FF9AA6"
headerBackground = "#160608"
titleBarBackgroundActive = "#3A1118"
titleBarBackgroundInactive = "#160608"
statusLineForegroundActive = "#FF9AA6"
statusLineForegroundInactive = "#9E5962"
statusLineBackground = "#160608"
paneBorderKeyboardTarget = "#FF9AA6"
paneBorderActive = "#9E5962"
paneBorderInactive = "#5A2530"
folderTreeBackground = "#0B0304"
folderTreeForeground = "#F4D7D9"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#FF6B7A"
folderTreeSelectedActive = "#3A1118"
folderTreeSelectedInactive = "#220A0F"
folderTreeSectionHeader = "#FF9AA6"
splitHandleIdle = "#5A2530"
splitHandleActive = "#FF9AA6"
```

## Vim / Neovim 風ダーク

### 9. Solar Night

```toml
[colors]
fileListBackground = "#002B36"
fileListRowSelected = "#073642"
fileListRowDropTarget = "#005F6B"
fileForeground = "#EEE8D5"
directoryForeground = "#268BD2"
secondaryForeground = "#839496"
headerForeground = "#B58900"
headerBackground = "#073642"
titleBarBackgroundActive = "#124653"
titleBarBackgroundInactive = "#073642"
statusLineForegroundActive = "#B58900"
statusLineForegroundInactive = "#839496"
statusLineBackground = "#073642"
paneBorderKeyboardTarget = "#B58900"
paneBorderActive = "#268BD2"
paneBorderInactive = "#586E75"
folderTreeBackground = "#002B36"
folderTreeForeground = "#EEE8D5"
folderTreeSelectedForeground = "#FDF6E3"
folderTreeFolderIcon = "#268BD2"
folderTreeSelectedActive = "#124653"
folderTreeSelectedInactive = "#073642"
folderTreeSectionHeader = "#B58900"
splitHandleIdle = "#586E75"
splitHandleActive = "#B58900"
```

### 10. Gruvbox Cave

```toml
[colors]
fileListBackground = "#1D2021"
fileListRowSelected = "#3C3836"
fileListRowDropTarget = "#504945"
fileForeground = "#EBDBB2"
directoryForeground = "#FABD2F"
secondaryForeground = "#A89984"
headerForeground = "#B8BB26"
headerBackground = "#282828"
titleBarBackgroundActive = "#504945"
titleBarBackgroundInactive = "#282828"
statusLineForegroundActive = "#B8BB26"
statusLineForegroundInactive = "#A89984"
statusLineBackground = "#282828"
paneBorderKeyboardTarget = "#B8BB26"
paneBorderActive = "#D79921"
paneBorderInactive = "#665C54"
folderTreeBackground = "#1D2021"
folderTreeForeground = "#EBDBB2"
folderTreeSelectedForeground = "#FBF1C7"
folderTreeFolderIcon = "#FABD2F"
folderTreeSelectedActive = "#504945"
folderTreeSelectedInactive = "#3C3836"
folderTreeSectionHeader = "#B8BB26"
splitHandleIdle = "#665C54"
splitHandleActive = "#B8BB26"
```

### 11. Dracula Velvet

```toml
[colors]
fileListBackground = "#282A36"
fileListRowSelected = "#44475A"
fileListRowDropTarget = "#5D4D7A"
fileForeground = "#F8F8F2"
directoryForeground = "#BD93F9"
secondaryForeground = "#A6ACCD"
headerForeground = "#FF79C6"
headerBackground = "#21222C"
titleBarBackgroundActive = "#44475A"
titleBarBackgroundInactive = "#21222C"
statusLineForegroundActive = "#FF79C6"
statusLineForegroundInactive = "#A6ACCD"
statusLineBackground = "#21222C"
paneBorderKeyboardTarget = "#FF79C6"
paneBorderActive = "#BD93F9"
paneBorderInactive = "#6272A4"
folderTreeBackground = "#282A36"
folderTreeForeground = "#F8F8F2"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#BD93F9"
folderTreeSelectedActive = "#44475A"
folderTreeSelectedInactive = "#343746"
folderTreeSectionHeader = "#FF79C6"
splitHandleIdle = "#6272A4"
splitHandleActive = "#FF79C6"
```

### 12. Tokyo Midnight

```toml
[colors]
fileListBackground = "#1A1B26"
fileListRowSelected = "#2F3549"
fileListRowDropTarget = "#364A7A"
fileForeground = "#C0CAF5"
directoryForeground = "#7AA2F7"
secondaryForeground = "#787C99"
headerForeground = "#BB9AF7"
headerBackground = "#16161E"
titleBarBackgroundActive = "#2F3549"
titleBarBackgroundInactive = "#16161E"
statusLineForegroundActive = "#BB9AF7"
statusLineForegroundInactive = "#787C99"
statusLineBackground = "#16161E"
paneBorderKeyboardTarget = "#BB9AF7"
paneBorderActive = "#7AA2F7"
paneBorderInactive = "#414868"
folderTreeBackground = "#1A1B26"
folderTreeForeground = "#C0CAF5"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#7AA2F7"
folderTreeSelectedActive = "#2F3549"
folderTreeSelectedInactive = "#24283B"
folderTreeSectionHeader = "#BB9AF7"
splitHandleIdle = "#414868"
splitHandleActive = "#BB9AF7"
```

### 13. Nord Fjord

```toml
[colors]
fileListBackground = "#2E3440"
fileListRowSelected = "#3B4252"
fileListRowDropTarget = "#405A6B"
fileForeground = "#ECEFF4"
directoryForeground = "#88C0D0"
secondaryForeground = "#A3B1C6"
headerForeground = "#81A1C1"
headerBackground = "#252A33"
titleBarBackgroundActive = "#434C5E"
titleBarBackgroundInactive = "#252A33"
statusLineForegroundActive = "#81A1C1"
statusLineForegroundInactive = "#A3B1C6"
statusLineBackground = "#252A33"
paneBorderKeyboardTarget = "#81A1C1"
paneBorderActive = "#88C0D0"
paneBorderInactive = "#4C566A"
folderTreeBackground = "#2E3440"
folderTreeForeground = "#ECEFF4"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#88C0D0"
folderTreeSelectedActive = "#434C5E"
folderTreeSelectedInactive = "#3B4252"
folderTreeSectionHeader = "#81A1C1"
splitHandleIdle = "#4C566A"
splitHandleActive = "#81A1C1"
```

### 14. One Dark Alloy

```toml
[colors]
fileListBackground = "#282C34"
fileListRowSelected = "#3A3F4B"
fileListRowDropTarget = "#3E5668"
fileForeground = "#ABB2BF"
directoryForeground = "#61AFEF"
secondaryForeground = "#7F848E"
headerForeground = "#98C379"
headerBackground = "#21252B"
titleBarBackgroundActive = "#3A3F4B"
titleBarBackgroundInactive = "#21252B"
statusLineForegroundActive = "#98C379"
statusLineForegroundInactive = "#7F848E"
statusLineBackground = "#21252B"
paneBorderKeyboardTarget = "#98C379"
paneBorderActive = "#61AFEF"
paneBorderInactive = "#4B5263"
folderTreeBackground = "#282C34"
folderTreeForeground = "#ABB2BF"
folderTreeSelectedForeground = "#E6EFFA"
folderTreeFolderIcon = "#61AFEF"
folderTreeSelectedActive = "#3A3F4B"
folderTreeSelectedInactive = "#313640"
folderTreeSectionHeader = "#98C379"
splitHandleIdle = "#4B5263"
splitHandleActive = "#98C379"
```

### 15. Monokai Neon

```toml
[colors]
fileListBackground = "#272822"
fileListRowSelected = "#3E3D32"
fileListRowDropTarget = "#4E5B28"
fileForeground = "#F8F8F2"
directoryForeground = "#A6E22E"
secondaryForeground = "#A59F85"
headerForeground = "#FD971F"
headerBackground = "#1F201B"
titleBarBackgroundActive = "#49483E"
titleBarBackgroundInactive = "#1F201B"
statusLineForegroundActive = "#FD971F"
statusLineForegroundInactive = "#A59F85"
statusLineBackground = "#1F201B"
paneBorderKeyboardTarget = "#FD971F"
paneBorderActive = "#A6E22E"
paneBorderInactive = "#75715E"
folderTreeBackground = "#272822"
folderTreeForeground = "#F8F8F2"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#A6E22E"
folderTreeSelectedActive = "#49483E"
folderTreeSelectedInactive = "#3E3D32"
folderTreeSectionHeader = "#FD971F"
splitHandleIdle = "#75715E"
splitHandleActive = "#FD971F"
```

### 16. Kanagawa Ink

```toml
[colors]
fileListBackground = "#1F1F28"
fileListRowSelected = "#2A2A37"
fileListRowDropTarget = "#364A4A"
fileForeground = "#DCD7BA"
directoryForeground = "#7E9CD8"
secondaryForeground = "#8A8A8A"
headerForeground = "#E6C384"
headerBackground = "#16161D"
titleBarBackgroundActive = "#363646"
titleBarBackgroundInactive = "#16161D"
statusLineForegroundActive = "#E6C384"
statusLineForegroundInactive = "#8A8A8A"
statusLineBackground = "#16161D"
paneBorderKeyboardTarget = "#E6C384"
paneBorderActive = "#7E9CD8"
paneBorderInactive = "#54546D"
folderTreeBackground = "#1F1F28"
folderTreeForeground = "#DCD7BA"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#7E9CD8"
folderTreeSelectedActive = "#363646"
folderTreeSelectedInactive = "#2A2A37"
folderTreeSectionHeader = "#E6C384"
splitHandleIdle = "#54546D"
splitHandleActive = "#E6C384"
```

### 17. Catppuccin Mocha

```toml
[colors]
fileListBackground = "#1E1E2E"
fileListRowSelected = "#313244"
fileListRowDropTarget = "#45475A"
fileForeground = "#CDD6F4"
directoryForeground = "#89B4FA"
secondaryForeground = "#A6ADC8"
headerForeground = "#F5C2E7"
headerBackground = "#181825"
titleBarBackgroundActive = "#313244"
titleBarBackgroundInactive = "#181825"
statusLineForegroundActive = "#F5C2E7"
statusLineForegroundInactive = "#A6ADC8"
statusLineBackground = "#181825"
paneBorderKeyboardTarget = "#F5C2E7"
paneBorderActive = "#89B4FA"
paneBorderInactive = "#585B70"
folderTreeBackground = "#1E1E2E"
folderTreeForeground = "#CDD6F4"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#89B4FA"
folderTreeSelectedActive = "#313244"
folderTreeSelectedInactive = "#292A3A"
folderTreeSectionHeader = "#F5C2E7"
splitHandleIdle = "#585B70"
splitHandleActive = "#F5C2E7"
```

### 18. Everforest Deep

```toml
[colors]
fileListBackground = "#1E2326"
fileListRowSelected = "#2E383C"
fileListRowDropTarget = "#3A5150"
fileForeground = "#D3C6AA"
directoryForeground = "#A7C080"
secondaryForeground = "#859289"
headerForeground = "#DBBC7F"
headerBackground = "#171C1F"
titleBarBackgroundActive = "#374145"
titleBarBackgroundInactive = "#171C1F"
statusLineForegroundActive = "#DBBC7F"
statusLineForegroundInactive = "#859289"
statusLineBackground = "#171C1F"
paneBorderKeyboardTarget = "#DBBC7F"
paneBorderActive = "#A7C080"
paneBorderInactive = "#4F5B58"
folderTreeBackground = "#1E2326"
folderTreeForeground = "#D3C6AA"
folderTreeSelectedForeground = "#F2E8C9"
folderTreeFolderIcon = "#A7C080"
folderTreeSelectedActive = "#374145"
folderTreeSelectedInactive = "#2E383C"
folderTreeSectionHeader = "#DBBC7F"
splitHandleIdle = "#4F5B58"
splitHandleActive = "#DBBC7F"
```

## モダンダーク / oh-my-posh 風

### 19. Powerline Graphite

```toml
[colors]
fileListBackground = "#111317"
fileListRowSelected = "#252A33"
fileListRowDropTarget = "#26495C"
fileForeground = "#D8DEE9"
directoryForeground = "#66D9EF"
secondaryForeground = "#8B95A1"
headerForeground = "#A6E22E"
headerBackground = "#171A20"
titleBarBackgroundActive = "#2F3642"
titleBarBackgroundInactive = "#171A20"
statusLineForegroundActive = "#A6E22E"
statusLineForegroundInactive = "#8B95A1"
statusLineBackground = "#171A20"
paneBorderKeyboardTarget = "#A6E22E"
paneBorderActive = "#66D9EF"
paneBorderInactive = "#3E4652"
folderTreeBackground = "#111317"
folderTreeForeground = "#D8DEE9"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#66D9EF"
folderTreeSelectedActive = "#2F3642"
folderTreeSelectedInactive = "#20252D"
folderTreeSectionHeader = "#A6E22E"
splitHandleIdle = "#3E4652"
splitHandleActive = "#A6E22E"
```

### 20. Cyber Ocean

```toml
[colors]
fileListBackground = "#06151F"
fileListRowSelected = "#0A2B3F"
fileListRowDropTarget = "#0B5268"
fileForeground = "#D7F9FF"
directoryForeground = "#00D7FF"
secondaryForeground = "#5CA3B7"
headerForeground = "#00FFB3"
headerBackground = "#071018"
titleBarBackgroundActive = "#0B344A"
titleBarBackgroundInactive = "#071018"
statusLineForegroundActive = "#00FFB3"
statusLineForegroundInactive = "#5CA3B7"
statusLineBackground = "#071018"
paneBorderKeyboardTarget = "#00FFB3"
paneBorderActive = "#00D7FF"
paneBorderInactive = "#1A5E72"
folderTreeBackground = "#06151F"
folderTreeForeground = "#D7F9FF"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#00D7FF"
folderTreeSelectedActive = "#0B344A"
folderTreeSelectedInactive = "#0A2230"
folderTreeSectionHeader = "#00FFB3"
splitHandleIdle = "#1A5E72"
splitHandleActive = "#00FFB3"
```

### 21. Neon Berry

```toml
[colors]
fileListBackground = "#140B1F"
fileListRowSelected = "#2E1745"
fileListRowDropTarget = "#5C2470"
fileForeground = "#F4E9FF"
directoryForeground = "#FF5FD2"
secondaryForeground = "#9D7CB7"
headerForeground = "#BD93F9"
headerBackground = "#1D0F2B"
titleBarBackgroundActive = "#3A1D56"
titleBarBackgroundInactive = "#1D0F2B"
statusLineForegroundActive = "#BD93F9"
statusLineForegroundInactive = "#9D7CB7"
statusLineBackground = "#1D0F2B"
paneBorderKeyboardTarget = "#BD93F9"
paneBorderActive = "#FF5FD2"
paneBorderInactive = "#6C4A84"
folderTreeBackground = "#140B1F"
folderTreeForeground = "#F4E9FF"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#FF5FD2"
folderTreeSelectedActive = "#3A1D56"
folderTreeSelectedInactive = "#29143D"
folderTreeSectionHeader = "#BD93F9"
splitHandleIdle = "#6C4A84"
splitHandleActive = "#BD93F9"
```

### 22. Mint Matrix

```toml
[colors]
fileListBackground = "#07120E"
fileListRowSelected = "#11281E"
fileListRowDropTarget = "#1F4C34"
fileForeground = "#D9FBE8"
directoryForeground = "#61F2A0"
secondaryForeground = "#6AA785"
headerForeground = "#9AFFC7"
headerBackground = "#0A1912"
titleBarBackgroundActive = "#173624"
titleBarBackgroundInactive = "#0A1912"
statusLineForegroundActive = "#9AFFC7"
statusLineForegroundInactive = "#6AA785"
statusLineBackground = "#0A1912"
paneBorderKeyboardTarget = "#9AFFC7"
paneBorderActive = "#61F2A0"
paneBorderInactive = "#2A6044"
folderTreeBackground = "#07120E"
folderTreeForeground = "#D9FBE8"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#61F2A0"
folderTreeSelectedActive = "#173624"
folderTreeSelectedInactive = "#102419"
folderTreeSectionHeader = "#9AFFC7"
splitHandleIdle = "#2A6044"
splitHandleActive = "#9AFFC7"
```

### 23. Lava Shell

```toml
[colors]
fileListBackground = "#160B08"
fileListRowSelected = "#3B1A12"
fileListRowDropTarget = "#71321C"
fileForeground = "#FFE5D2"
directoryForeground = "#FF8A3D"
secondaryForeground = "#B57455"
headerForeground = "#FFD166"
headerBackground = "#200E09"
titleBarBackgroundActive = "#4A2116"
titleBarBackgroundInactive = "#200E09"
statusLineForegroundActive = "#FFD166"
statusLineForegroundInactive = "#B57455"
statusLineBackground = "#200E09"
paneBorderKeyboardTarget = "#FFD166"
paneBorderActive = "#FF8A3D"
paneBorderInactive = "#6A3C2A"
folderTreeBackground = "#160B08"
folderTreeForeground = "#FFE5D2"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#FF8A3D"
folderTreeSelectedActive = "#4A2116"
folderTreeSelectedInactive = "#2E150E"
folderTreeSectionHeader = "#FFD166"
splitHandleIdle = "#6A3C2A"
splitHandleActive = "#FFD166"
```

### 24. Space Cadet

```toml
[colors]
fileListBackground = "#101322"
fileListRowSelected = "#242B45"
fileListRowDropTarget = "#34406C"
fileForeground = "#E2E8FF"
directoryForeground = "#7FDBFF"
secondaryForeground = "#8B93B0"
headerForeground = "#FFDC7A"
headerBackground = "#0B0E1A"
titleBarBackgroundActive = "#30385A"
titleBarBackgroundInactive = "#0B0E1A"
statusLineForegroundActive = "#FFDC7A"
statusLineForegroundInactive = "#8B93B0"
statusLineBackground = "#0B0E1A"
paneBorderKeyboardTarget = "#FFDC7A"
paneBorderActive = "#7FDBFF"
paneBorderInactive = "#4B5578"
folderTreeBackground = "#101322"
folderTreeForeground = "#E2E8FF"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#7FDBFF"
folderTreeSelectedActive = "#30385A"
folderTreeSelectedInactive = "#1B2138"
folderTreeSectionHeader = "#FFDC7A"
splitHandleIdle = "#4B5578"
splitHandleActive = "#FFDC7A"
```

### 25. Orchid Terminal

```toml
[colors]
fileListBackground = "#17111D"
fileListRowSelected = "#2D2037"
fileListRowDropTarget = "#503064"
fileForeground = "#F0E7F7"
directoryForeground = "#C792EA"
secondaryForeground = "#9A88A8"
headerForeground = "#F78C6C"
headerBackground = "#100C14"
titleBarBackgroundActive = "#392847"
titleBarBackgroundInactive = "#100C14"
statusLineForegroundActive = "#F78C6C"
statusLineForegroundInactive = "#9A88A8"
statusLineBackground = "#100C14"
paneBorderKeyboardTarget = "#F78C6C"
paneBorderActive = "#C792EA"
paneBorderInactive = "#574364"
folderTreeBackground = "#17111D"
folderTreeForeground = "#F0E7F7"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#C792EA"
folderTreeSelectedActive = "#392847"
folderTreeSelectedInactive = "#241A2C"
folderTreeSectionHeader = "#F78C6C"
splitHandleIdle = "#574364"
splitHandleActive = "#F78C6C"
```

### 26. Steel Pulse

```toml
[colors]
fileListBackground = "#111820"
fileListRowSelected = "#23313D"
fileListRowDropTarget = "#344B5C"
fileForeground = "#D8E1EA"
directoryForeground = "#8CC8FF"
secondaryForeground = "#7E8D9A"
headerForeground = "#F0B35A"
headerBackground = "#0C1218"
titleBarBackgroundActive = "#2D3D4A"
titleBarBackgroundInactive = "#0C1218"
statusLineForegroundActive = "#F0B35A"
statusLineForegroundInactive = "#7E8D9A"
statusLineBackground = "#0C1218"
paneBorderKeyboardTarget = "#F0B35A"
paneBorderActive = "#8CC8FF"
paneBorderInactive = "#455768"
folderTreeBackground = "#111820"
folderTreeForeground = "#D8E1EA"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#8CC8FF"
folderTreeSelectedActive = "#2D3D4A"
folderTreeSelectedInactive = "#1B2630"
folderTreeSectionHeader = "#F0B35A"
splitHandleIdle = "#455768"
splitHandleActive = "#F0B35A"
```

### 27. Ruby Smoke

```toml
[colors]
fileListBackground = "#151012"
fileListRowSelected = "#2E2025"
fileListRowDropTarget = "#53313A"
fileForeground = "#F2E5E8"
directoryForeground = "#FF6E8A"
secondaryForeground = "#9E8088"
headerForeground = "#FFB86C"
headerBackground = "#0F0B0D"
titleBarBackgroundActive = "#3A2930"
titleBarBackgroundInactive = "#0F0B0D"
statusLineForegroundActive = "#FFB86C"
statusLineForegroundInactive = "#9E8088"
statusLineBackground = "#0F0B0D"
paneBorderKeyboardTarget = "#FFB86C"
paneBorderActive = "#FF6E8A"
paneBorderInactive = "#5C444A"
folderTreeBackground = "#151012"
folderTreeForeground = "#F2E5E8"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#FF6E8A"
folderTreeSelectedActive = "#3A2930"
folderTreeSelectedInactive = "#251A1F"
folderTreeSectionHeader = "#FFB86C"
splitHandleIdle = "#5C444A"
splitHandleActive = "#FFB86C"
```

### 28. Aqua Minimal

```toml
[colors]
fileListBackground = "#071113"
fileListRowSelected = "#10282C"
fileListRowDropTarget = "#17474E"
fileForeground = "#D6F7F5"
directoryForeground = "#5EF0EA"
secondaryForeground = "#70A6A5"
headerForeground = "#B4F8C8"
headerBackground = "#050D0F"
titleBarBackgroundActive = "#173236"
titleBarBackgroundInactive = "#050D0F"
statusLineForegroundActive = "#B4F8C8"
statusLineForegroundInactive = "#70A6A5"
statusLineBackground = "#050D0F"
paneBorderKeyboardTarget = "#B4F8C8"
paneBorderActive = "#5EF0EA"
paneBorderInactive = "#2D5E64"
folderTreeBackground = "#071113"
folderTreeForeground = "#D6F7F5"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#5EF0EA"
folderTreeSelectedActive = "#173236"
folderTreeSelectedInactive = "#0D2023"
folderTreeSectionHeader = "#B4F8C8"
splitHandleIdle = "#2D5E64"
splitHandleActive = "#B4F8C8"
```

## ライトモード

### 29. Solar Day

```toml
[colors]
fileListBackground = "#FDF6E3"
fileListRowSelected = "#EEE8D5"
fileListRowDropTarget = "#D8E8D4"
fileForeground = "#073642"
directoryForeground = "#268BD2"
secondaryForeground = "#657B83"
headerForeground = "#B58900"
headerBackground = "#F3EBCF"
titleBarBackgroundActive = "#E6DFC8"
titleBarBackgroundInactive = "#F3EBCF"
statusLineForegroundActive = "#B58900"
statusLineForegroundInactive = "#657B83"
statusLineBackground = "#F3EBCF"
paneBorderKeyboardTarget = "#B58900"
paneBorderActive = "#268BD2"
paneBorderInactive = "#93A1A1"
folderTreeBackground = "#F8F0D8"
folderTreeForeground = "#073642"
folderTreeSelectedForeground = "#002B36"
folderTreeFolderIcon = "#268BD2"
folderTreeSelectedActive = "#E6DFC8"
folderTreeSelectedInactive = "#EEE8D5"
folderTreeSectionHeader = "#B58900"
splitHandleIdle = "#93A1A1"
splitHandleActive = "#B58900"
```

### 30. Catppuccin Latte

```toml
[colors]
fileListBackground = "#EFF1F5"
fileListRowSelected = "#DCE0E8"
fileListRowDropTarget = "#CCD0DA"
fileForeground = "#4C4F69"
directoryForeground = "#1E66F5"
secondaryForeground = "#6C6F85"
headerForeground = "#8839EF"
headerBackground = "#E6E9EF"
titleBarBackgroundActive = "#DCE0E8"
titleBarBackgroundInactive = "#E6E9EF"
statusLineForegroundActive = "#8839EF"
statusLineForegroundInactive = "#6C6F85"
statusLineBackground = "#E6E9EF"
paneBorderKeyboardTarget = "#8839EF"
paneBorderActive = "#1E66F5"
paneBorderInactive = "#BCC0CC"
folderTreeBackground = "#EFF1F5"
folderTreeForeground = "#4C4F69"
folderTreeSelectedForeground = "#1E1E2E"
folderTreeFolderIcon = "#1E66F5"
folderTreeSelectedActive = "#DCE0E8"
folderTreeSelectedInactive = "#E6E9EF"
folderTreeSectionHeader = "#8839EF"
splitHandleIdle = "#BCC0CC"
splitHandleActive = "#8839EF"
```

### 31. GitHub Light

```toml
[colors]
fileListBackground = "#FFFFFF"
fileListRowSelected = "#DDF4FF"
fileListRowDropTarget = "#B6E3FF"
fileForeground = "#24292F"
directoryForeground = "#0969DA"
secondaryForeground = "#57606A"
headerForeground = "#0969DA"
headerBackground = "#F6F8FA"
titleBarBackgroundActive = "#DDF4FF"
titleBarBackgroundInactive = "#F6F8FA"
statusLineForegroundActive = "#0969DA"
statusLineForegroundInactive = "#57606A"
statusLineBackground = "#F6F8FA"
paneBorderKeyboardTarget = "#0969DA"
paneBorderActive = "#54AEFF"
paneBorderInactive = "#D0D7DE"
folderTreeBackground = "#FFFFFF"
folderTreeForeground = "#24292F"
folderTreeSelectedForeground = "#0969DA"
folderTreeFolderIcon = "#0969DA"
folderTreeSelectedActive = "#DDF4FF"
folderTreeSelectedInactive = "#F6F8FA"
folderTreeSectionHeader = "#0969DA"
splitHandleIdle = "#D0D7DE"
splitHandleActive = "#0969DA"
```

### 32. Paper Mint

```toml
[colors]
fileListBackground = "#F7FAF5"
fileListRowSelected = "#DDEFD8"
fileListRowDropTarget = "#BEE5B7"
fileForeground = "#18221A"
directoryForeground = "#167A3A"
secondaryForeground = "#5D6B60"
headerForeground = "#1C6B37"
headerBackground = "#EAF3E7"
titleBarBackgroundActive = "#D5EBD0"
titleBarBackgroundInactive = "#EAF3E7"
statusLineForegroundActive = "#176B34"
statusLineForegroundInactive = "#5D6B60"
statusLineBackground = "#EAF3E7"
paneBorderKeyboardTarget = "#17813A"
paneBorderActive = "#6AA66F"
paneBorderInactive = "#C5D5C2"
folderTreeBackground = "#F2F7EF"
folderTreeForeground = "#18221A"
folderTreeSelectedForeground = "#0E2614"
folderTreeFolderIcon = "#167A3A"
folderTreeSelectedActive = "#D5EBD0"
folderTreeSelectedInactive = "#E3EFE0"
folderTreeSectionHeader = "#1C6B37"
splitHandleIdle = "#C5D5C2"
splitHandleActive = "#17813A"
```

### 33. Warm Notebook

```toml
[colors]
fileListBackground = "#FFF8ED"
fileListRowSelected = "#F0E0C8"
fileListRowDropTarget = "#E8CFA8"
fileForeground = "#2D251C"
directoryForeground = "#A35F00"
secondaryForeground = "#74665A"
headerForeground = "#8A4E00"
headerBackground = "#F5EBDD"
titleBarBackgroundActive = "#EEDBC0"
titleBarBackgroundInactive = "#F5EBDD"
statusLineForegroundActive = "#8A4E00"
statusLineForegroundInactive = "#74665A"
statusLineBackground = "#F5EBDD"
paneBorderKeyboardTarget = "#A35F00"
paneBorderActive = "#B98B4A"
paneBorderInactive = "#D7C6AF"
folderTreeBackground = "#FFF3E0"
folderTreeForeground = "#2D251C"
folderTreeSelectedForeground = "#1A120C"
folderTreeFolderIcon = "#A35F00"
folderTreeSelectedActive = "#EEDBC0"
folderTreeSelectedInactive = "#F5EBDD"
folderTreeSectionHeader = "#8A4E00"
splitHandleIdle = "#D7C6AF"
splitHandleActive = "#A35F00"
```

### 34. Frosted Light

```toml
[colors]
fileListBackground = "#F4F8FB"
fileListRowSelected = "#DCECF7"
fileListRowDropTarget = "#C9E5F5"
fileForeground = "#1F2A33"
directoryForeground = "#0077B6"
secondaryForeground = "#667782"
headerForeground = "#005F8C"
headerBackground = "#E8F1F7"
titleBarBackgroundActive = "#D7EAF5"
titleBarBackgroundInactive = "#E8F1F7"
statusLineForegroundActive = "#005F8C"
statusLineForegroundInactive = "#667782"
statusLineBackground = "#E8F1F7"
paneBorderKeyboardTarget = "#0077B6"
paneBorderActive = "#68A9CF"
paneBorderInactive = "#C2D1DA"
folderTreeBackground = "#F4F8FB"
folderTreeForeground = "#1F2A33"
folderTreeSelectedForeground = "#0D2535"
folderTreeFolderIcon = "#0077B6"
folderTreeSelectedActive = "#D7EAF5"
folderTreeSelectedInactive = "#E8F1F7"
folderTreeSectionHeader = "#005F8C"
splitHandleIdle = "#C2D1DA"
splitHandleActive = "#0077B6"
```

### 35. Rose Light

```toml
[colors]
fileListBackground = "#FFF7F8"
fileListRowSelected = "#F7DCE2"
fileListRowDropTarget = "#F2C4D1"
fileForeground = "#332126"
directoryForeground = "#C43B67"
secondaryForeground = "#7B6268"
headerForeground = "#A92855"
headerBackground = "#F8E8EC"
titleBarBackgroundActive = "#F2D5DC"
titleBarBackgroundInactive = "#F8E8EC"
statusLineForegroundActive = "#A92855"
statusLineForegroundInactive = "#7B6268"
statusLineBackground = "#F8E8EC"
paneBorderKeyboardTarget = "#C43B67"
paneBorderActive = "#D98AA2"
paneBorderInactive = "#DFC0C8"
folderTreeBackground = "#FFF7F8"
folderTreeForeground = "#332126"
folderTreeSelectedForeground = "#1F1115"
folderTreeFolderIcon = "#C43B67"
folderTreeSelectedActive = "#F2D5DC"
folderTreeSelectedInactive = "#F8E8EC"
folderTreeSectionHeader = "#A92855"
splitHandleIdle = "#DFC0C8"
splitHandleActive = "#C43B67"
```

### 36. High Contrast Light

```toml
[colors]
fileListBackground = "#FFFFFF"
fileListRowSelected = "#D7E7FF"
fileListRowDropTarget = "#B8D8FF"
fileForeground = "#000000"
directoryForeground = "#0046B8"
secondaryForeground = "#444444"
headerForeground = "#002B80"
headerBackground = "#EFEFEF"
titleBarBackgroundActive = "#D7E7FF"
titleBarBackgroundInactive = "#EFEFEF"
statusLineForegroundActive = "#002B80"
statusLineForegroundInactive = "#444444"
statusLineBackground = "#EFEFEF"
paneBorderKeyboardTarget = "#002B80"
paneBorderActive = "#0046B8"
paneBorderInactive = "#AAAAAA"
folderTreeBackground = "#FFFFFF"
folderTreeForeground = "#000000"
folderTreeSelectedForeground = "#000000"
folderTreeFolderIcon = "#0046B8"
folderTreeSelectedActive = "#D7E7FF"
folderTreeSelectedInactive = "#EFEFEF"
folderTreeSectionHeader = "#002B80"
splitHandleIdle = "#AAAAAA"
splitHandleActive = "#002B80"
```

## ソフト / 低刺激

### 37. Low Contrast Slate

```toml
[colors]
fileListBackground = "#20242A"
fileListRowSelected = "#2D333B"
fileListRowDropTarget = "#38414B"
fileForeground = "#C9D1D9"
directoryForeground = "#8BA7C9"
secondaryForeground = "#8B949E"
headerForeground = "#B6C2D1"
headerBackground = "#1A1E23"
titleBarBackgroundActive = "#303742"
titleBarBackgroundInactive = "#1A1E23"
statusLineForegroundActive = "#B6C2D1"
statusLineForegroundInactive = "#8B949E"
statusLineBackground = "#1A1E23"
paneBorderKeyboardTarget = "#B6C2D1"
paneBorderActive = "#8BA7C9"
paneBorderInactive = "#48515C"
folderTreeBackground = "#20242A"
folderTreeForeground = "#C9D1D9"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#8BA7C9"
folderTreeSelectedActive = "#303742"
folderTreeSelectedInactive = "#272D34"
folderTreeSectionHeader = "#B6C2D1"
splitHandleIdle = "#48515C"
splitHandleActive = "#B6C2D1"
```

### 38. Coffee Soft

```toml
[colors]
fileListBackground = "#211B17"
fileListRowSelected = "#332920"
fileListRowDropTarget = "#4A382A"
fileForeground = "#E5D6C8"
directoryForeground = "#D1A36F"
secondaryForeground = "#9A8472"
headerForeground = "#CBB08A"
headerBackground = "#18130F"
titleBarBackgroundActive = "#3A2E25"
titleBarBackgroundInactive = "#18130F"
statusLineForegroundActive = "#CBB08A"
statusLineForegroundInactive = "#9A8472"
statusLineBackground = "#18130F"
paneBorderKeyboardTarget = "#CBB08A"
paneBorderActive = "#D1A36F"
paneBorderInactive = "#57483D"
folderTreeBackground = "#211B17"
folderTreeForeground = "#E5D6C8"
folderTreeSelectedForeground = "#FFF4E8"
folderTreeFolderIcon = "#D1A36F"
folderTreeSelectedActive = "#3A2E25"
folderTreeSelectedInactive = "#2A221D"
folderTreeSectionHeader = "#CBB08A"
splitHandleIdle = "#57483D"
splitHandleActive = "#CBB08A"
```

### 39. Forest Night

```toml
[colors]
fileListBackground = "#111A14"
fileListRowSelected = "#1F2E23"
fileListRowDropTarget = "#2E4A34"
fileForeground = "#D9E6D5"
directoryForeground = "#8FBC8F"
secondaryForeground = "#7D917D"
headerForeground = "#B6D68A"
headerBackground = "#0B120E"
titleBarBackgroundActive = "#293B2D"
titleBarBackgroundInactive = "#0B120E"
statusLineForegroundActive = "#B6D68A"
statusLineForegroundInactive = "#7D917D"
statusLineBackground = "#0B120E"
paneBorderKeyboardTarget = "#B6D68A"
paneBorderActive = "#8FBC8F"
paneBorderInactive = "#405A42"
folderTreeBackground = "#111A14"
folderTreeForeground = "#D9E6D5"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#8FBC8F"
folderTreeSelectedActive = "#293B2D"
folderTreeSelectedInactive = "#1B261D"
folderTreeSectionHeader = "#B6D68A"
splitHandleIdle = "#405A42"
splitHandleActive = "#B6D68A"
```

### 40. Accessibility Dark

```toml
[colors]
fileListBackground = "#000000"
fileListRowSelected = "#1E3A5F"
fileListRowDropTarget = "#245A34"
fileForeground = "#FFFFFF"
directoryForeground = "#66CCFF"
secondaryForeground = "#C8C8C8"
headerForeground = "#FFFF66"
headerBackground = "#101010"
titleBarBackgroundActive = "#1E3A5F"
titleBarBackgroundInactive = "#101010"
statusLineForegroundActive = "#FFFF66"
statusLineForegroundInactive = "#C8C8C8"
statusLineBackground = "#101010"
paneBorderKeyboardTarget = "#FFFF66"
paneBorderActive = "#66CCFF"
paneBorderInactive = "#777777"
folderTreeBackground = "#000000"
folderTreeForeground = "#FFFFFF"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#66CCFF"
folderTreeSelectedActive = "#1E3A5F"
folderTreeSelectedInactive = "#1A1A1A"
folderTreeSectionHeader = "#FFFF66"
splitHandleIdle = "#777777"
splitHandleActive = "#FFFF66"
```
