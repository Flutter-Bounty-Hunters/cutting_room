<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/161407422-074272c2-2935-4eb4-94bc-dceda336c109.png" width="300" alt="Cutting Room"><br>
  <span><b>Compose and render videos with compositions, backed by FFMPEG.</b></span><br><br>
</p>

> This project is a Flutter Bounty Hunters [proof-of-concept](http://policies.flutterbountyhunters.com/about/proof-of-concept). Want more composition types and video controls? [Fund a milestone](http://policies.flutterbountyhunters.com/about/fund-a-milestone) today!

---

# In the wild
`cutting_room` is used to render all videos on the [Flutter Bounty Hunters Channel](https://www.youtube.com/channel/UCLcjoIESotPI-5VD-85k-jA) as well as the [SuperDeclarative! Channel](https://youtube.com/c/SuperDeclarative).

# Quickstart
In Cutting Room, what you're trying to do is compose a composition that will be rendered using FFMPEG.
When everything is said and done, a massive FFMPEG command will run at the command line and produce
your video.

Cutting Room gives you declarative compositions so that you can compose a video, kind of like how you
compose a Flutter widget tree. In the following example, a video is composed from two other video clips,
played back to back (in series).

```dart
// Compose the desired video and build an FFMPEG command
// to render it.
final cliCommand = await CompositionBuilder().build(
  // This is your declarative video composition, much like
  // a widget tree in Flutter.
  SeriesComposition(
    compositions: [
      FullVideoComposition(
        videoPath: "assets/Butterfly-209.mp4",
      ),
      FullVideoComposition(
        videoPath: "assets/bee.mp4",
      ),
    ],
  ),
);

// Run the FFMPEG command.
final process = await Ffmpeg().run(cliCommand);

// Pipe the process output to the Dart console.
process.stderr.transform(utf8.decoder).listen((data) {
  print(data);
});

// Allow the user to respond to FFMPEG queries, such as file overwrite
// confirmations.
stdin.pipe(process.stdin);

await process.exitCode;
```

# Types of Compositions
`cutting_room` ships with a number of compositions, including...

 * `SeriesComposition`
 * `LayeredComposition`
 * `ImageOverlayComposition`
 * and more.

If the `Composition`s that ship with `cutting_room` don't fit your needs, you can always define your own. To
implement a custom `Composition`, you need to understand how FFMPEG commands are defined, and then assemble
FFMPEG filters that accomplish your goal.

# Cutting Room Assets
Internally, `cutting_room` includes and uses a few assets. For example, `cutting_room` uses a PNG
image filled with black to render black compositions. There are various reasons why these assets
are used. In the future, `cutting_room` might find a way to get rid of them.

The important part is that these assets are files. These files are included with `cutting_room`,
and you shouldn't notice them when you're running your app with the `dart` tool. However, if you
compile your Dart app to a binary executable, you lose access to dependency assets, including
those in `cutting_room`. In this case, `cutting_room` will write these assets to new files on your
local file system when you run your app. For this reason, you shouldn't be surprised if some
generated image and video files appear wherever you run your video rendering.
