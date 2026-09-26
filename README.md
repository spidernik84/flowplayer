# FlowPlayer for SailfishOS / Experimental Fork

**FlowPlayer is a feature-rich music player for SailfishOS.**

**This is an experimental fork with moderately heavy use of LLMs, with the intention of fixing some bugs and introducing some features (read section below). The fork is being tested on a Jolla Phone 2026 which I personally own.**

## Warnings, background and LLM usage

Some advice: do NOT take this as an example of necessarily good coding. It's used only for my own experiments. I'm sharing it here nevertheless.
I am using it daily and it works well. As usual, use it at your own risk.
I started with Deepseek and recently switched to Claude.

NOTE: This shares the same config folder as the standard FlowPlayer so you may want to take a backup of your config directory, just in case (`~/.config/sailfishos-applications/flowplayer/`).

This has only been tested on Sailfish 5.1 on a Jolla Phone 2026. The requirements are essentially the same of upstream FlowPlayer but no testing has been performed on older releases of SailfishOS.

Scary-tone aside: the modifications have been introduced step-by-step, iteratively, and not in a single big-jump, bruteforcing my way through vibe-coding:
I created branches, tags and did my best to understand what the LLMs were changing.
I focused on single features, tested them one by one, ironed out the bugs and marched on.
While I am no professional, full-time programmer, I am no total stranger either: I have experience with Python scripting at least.

The documentation, merging, release notes, changelog entries and comments are hand-typed with love by yours truly (at least that I can still do).

## Thanks

Most importantly: all credit to the original developers who made this possible. I'm piggybacking greatly here.

## Contributing

You'll see some bugs and issues I created. Please feel free to add more, I'll do my best to consider what to add.
Testing is fundamental so please try it out, I'm particularly interested in how the changes manage big collections of music.

## Reason for the existence of this fork and what to do with it

The scope of the fork exercise is essentially:

- playing with the Sailfish SDK
- playing with development on Sailfish in general
- playing with LLMs

It's kept separate for the reasons explained in the beginning. In case the LLMs have produced useful changes to be merged upstream, please pick them!

## Changes and new features to the original FlowPlayer

**High Prio**

- [x] Implement better track management in the player
    - [x] sort by track number by default
    - [x] handle multi-cd albums
- [x] Multiple queuing strategies: in addition to "Add to (end of) the queue", now offers "Play Next"
- [x] cover loading from file first (prefer embedded, fallback to manual)
- [x] bulk cover loading fix
- [x] fix radio streaming
  - [x] change backend (now uses www.radio-browser.info)
  - [x] support ICECast metadata (Artist/Track title/Radio Name)
  - [x] remove progress bar and shuffle/repeat controls
- [x] implement "Queue entire album"
- [x] implement headphones event (play/pause/next track) // this needs further testing, it seemed already implemented but doesn't always work
- [x] Queue advanced editing
  - [x] Draggable items, even non contiguous (they become contiguous in that case)
  - [x] Send items to end of queue or to top of queue
  - [x] Send multiple items after now-playing track
- [ ] implement resume from last state
- [ ] implement "Queue entire playlist"
- [ ] implement different strategies for track management (filesystem based, metadata based, hybrid) 

**Low Prio**

- [x] Implement Lyrics download + synced highlight to playback
- [ ] Implement Queue in own menu section

**Won't implement**

- [x] Advanced Radio Paradise support (pre-download for offline playing, PSD). This should probably warrant a dedicated app. For now, it shows the artist and track name, and the cover.



## New Features Screenshots

|   |   |   | |
|:---:|:---:|:---:|:---:|
| ![Multi-CD album](./.xdata/screenshots/Screenshot_20260921_211607_001.png?raw=true) | ![Multi-CD album](./.xdata/screenshots/Screenshot_20260921_211620_001.png?raw=true) | ![Lyrics synced to playback](./.xdata/screenshots/Screenshot_20260921_211645_001.png?raw=true) | ![Add to Queue + Play Next](./.xdata/screenshots/Screenshot_20260925_200055_001.png?raw=true) |
| Multi-CD album  | Multi-CD Album  | Lyrics synced to playback  | Add to queue + play next |
| ![Queue entire album (grid view)](./.xdata/screenshots/Screenshot_20260925_201423_001.png?raw=true) | ![Queue entire album (list view)](./.xdata/screenshots/Screenshot_20260925_201520_001.png?raw=true) | ![Radio station search (radio-browser.info)](./.xdata/screenshots/Screenshot_20260926_082925_001.png?raw=true) | ![Radio playing with station logo](./.xdata/screenshots/Screenshot_20260926_083016_001.png?raw=true) |
| Queue entire album (grid view) | Queue entire album (list view) | Radio station search (radio-browser.info) | Radio playing with station logo |
| ![Radio now playing (Icecast metadata + cover)](./.xdata/screenshots/Screenshot_20260926_082838_001.png?raw=true) | ![Advanced Queue editor](./.xdata/screenshots/items_manager.png?raw=true) | ![Drag multiple selected tracks](./.xdata/screenshots/multi_drag.png?raw=true) | ![Play selected tracks next](./.xdata/screenshots/play_next.png?raw=true) |
| Radio now playing (Icecast metadata + cover) | Advanced Queue editor | Drag multiple selected tracks | Play selected tracks next |


## Features

#### Supported file formats
- ASF, FLAC, M4A, MP3, Ogg Vorbis / Opus, WAV and WMA

#### Playing
- Playlists
- Play queue
- 10-band equalizer
- Gapless playback (optional)

#### User interface
- Multiple album view modes
- Media controls on home screen and lock screen
- Available in Catalan, Danish, Dutch, English, Estonian, Finnish, French, German, Italian, Russian, Spanish and Swedish

#### Miscellaneous
- Metadata editor
- Lyrics support

#### Currently broken features
~~- Online radio~~
- Last.fm scrobbling

<br />
Pull requests with fixes, improvements and enhancements are welcome!

<br />
<br />

## Translating FlowPlayer (l10n / i18n)

If you want to translate FlowPlayer to a language it does not support yet or improve an extant translation, please [read the translations-README](./translations#readme).

<br />

## Screenshots of FlowPlayer

|       |       |       |       |
| :---: | :---: | :---: | :---: |
|       |       |       |       |
| ![Music Player](./.xdata/screenshots/screenshot-20150711134510.jpg?raw=true) | ![Song list (album)](./.xdata/screenshots/screenshot-20150711134427.jpg?raw=true) | ![Album covers](./.xdata/screenshots/screenshot-20150711134124.jpg?raw=true) | ![Albums by artist](./.xdata/screenshots/screenshot-20150711134236.jpg?raw=true) |
| Music Player | Song list (album) | Album covers | Albums by artist |
|       |       |       |       |
|       |       |       |       |
| ![Covers by artist](./.xdata/screenshots/screenshot-20150711134206.jpg?raw=true) | ![Playlists](./.xdata/screenshots/screenshot-20150711134443.jpg?raw=true) | ![FileCase's cover](./.xdata/screenshots/screenshot-20150711134615.jpg?raw=true) | ![Lyrics](./.xdata/screenshots/screenshot-20150701221204.jpg?raw=true)
| &nbsp;&nbsp;Covers&nbsp;by&nbsp;artist&nbsp;&nbsp;&nbsp; | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Playlists&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | FlowPlayer's&nbsp;cover | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Lyrics&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; |
|       |       |       |       |
<br />

## History of FlowPlayer

The original [FlowPlayer for SailfishOS (2015 - 2016)](https://openrepos.net/content/cepiperez/flowplayer-0#content) started as a port of [FlowPlayer for MeeGo-Harmattan (2014)](https://openrepos.net/content/cepiperez/flowplayer#content).  Both were solely written by [Matias Perez (CepiPerez)](https://github.com/CepiPerez).  In 2021 Matias [released the source code of FlowPlayer](https://github.com/sailfishos-applications/flowplayer/commits/master?after=c4f36e1cb3a80b7c7b220a379c9bdaca3a300113+49) by creating this git repository at GitHub.

In 2023 [olf (Olf0)](https://github.com/Olf0) overhauled infrastructure aspects, such as this README, a [new OpenRepos page](https://openrepos.net/content/olf/flowplayer#content), the [Transifex integration](https://github.com/sailfishos-applications/flowplayer/pull/7), making the spec file suitable for [the SailfishOS-OBS](https://build.sailfishos.org/) and [the SailfishOS:Chum community repository](https://github.com/sailfishos-chum/main/blob/main/Metadata.md) etc.

<br />

## Credits
#### Original author
[Matias Perez (CepiPerez)](https://github.com/CepiPerez)
#### Contributors
- [Damien Caliste (dcaliste)](https://github.com/dcaliste)
- [David Llewellyn-Jones (llewelld / flypig)](https://github.com/llewelld)
- [Elmeri Länsiharju (tuplasuhveli)](https://github.com/tuplasuhveli)
- [Mark Washeim (poetaster)](https://github.com/poetaster)
- [olf (Olf0)](https://github.com/Olf0)
- [Ruben de Smet (rubdos)](https://github.com/rubdos)
- [Tomasz Sterna (smokku)](https://github.com/smokku)
<br />

### License: [MPL 2.0](https://spdx.org/licenses/MPL-2.0-no-copyleft-exception.html)

