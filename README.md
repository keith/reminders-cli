# reminders-cli

A simple CLI for interacting with OS X reminders.

## Usage:

#### Show all lists

```
$ reminders show-lists
Soon
Eventually
```

#### Show reminders on a specific list

```
$ reminders show Soon
0 Write README
1 Ship reminders-cli
```

#### Complete an item on a list

```
$ reminders complete Soon 0
Completed 'Write README'
$ reminders show Soon
0 Ship reminders-cli
```

#### Add a reminder to a list

```
$ reminders add Soon Go to sleep
$ reminders show Soon
0 Ship reminders-cli
1 Go to sleep
```

## Installation:

#### With [Homebrew](http://brew.sh/)

```
$ brew install keith/formulae/reminders-cli
```

**NOTE** You must have Xcode 7.3.1 installed at
`/Applications/Xcode.app` for this to work correctly. If this isn't the
case you should build manually as described below.

#### Manually

Download the latest release from
[here](https://github.com/keith/reminders-cli/releases)

```
$ tar -zxvf reminders.tar.gz
$ mv reminders /usr/local/bin
$ rm reminders.tar.gz
```

#### Building manually

Install [swiftenv](https://github.com/kylef/swiftenv/)

```
$ cd reminders-cli
$ swiftenv install
$ swift build --configuration release
$ cp .build/release/reminders /usr/local/bin/reminders
```
