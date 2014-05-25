import java.awt.Image;
import java.awt.image.BufferedImage;
import java.awt.Toolkit;
import java.io.ByteArrayOutputStream;
import java.util.Arrays;
import java.util.Random;
import javax.imageio.ImageIO;

import gifAnimation.*;

/*******************************************************************************
 * user settings here
 */
int fps = 30;
String inputFilename = "input.gif";
String outputFilename = "output.gif";

/*******************************************************************************
 * some variables used by the script
 */
Random random = new Random(); // RNG
Toolkit toolkit = Toolkit.getDefaultToolkit(); // AWT toolkit for bytes->JPEG
GifMaker gifExport;
PImage[] displayFrames; // the finished frames that will be displayed
int delay = round(1000.0 / fps); // GIF delay
int currentFrame = 0; // to control output
boolean gifEncodingStarted = false;
boolean gifEncodingWanted = false;
boolean gifEncodingDone = false;

/*******************************************************************************
 * loads a gif into frames
 */
PImage[] loadGifToFrames(String filename) {
  Gif gif;
  try {
    gif = new Gif(this, filename);
  }
  catch (Exception e) {
    println("Couldn't open input file!");
    return null;
  }
  println("Loading GIF into frames...");
  PImage[] output = gif.getPImages();
  return output;
}

/*******************************************************************************
 * converts a JPEG byte array into PImage
 * http://processing.org/discourse/beta/num_1234546778.html
 */
PImage jpegBytesToFrame(byte[] input) {
  Image awtImage = toolkit.createImage(input);
  return loadImageMT(awtImage);
}

/*******************************************************************************
 * converts a PImage into a JPEG byte array
 * partially from http://wiki.processing.org/index.php/Save_as_JPEG
 * (by Yonas Sandbæk) 
 */
byte[] frameToJpegBytes(PImage srcimg) {
  ByteArrayOutputStream out = new ByteArrayOutputStream();
  BufferedImage img = new BufferedImage(srcimg.width, srcimg.height, 2);
  img = (BufferedImage) createImage(srcimg.width, srcimg.height);
  for (int i = 0; i < srcimg.width; i++)
    for (int j = 0; j < srcimg.height; j++)
      img.setRGB(i, j, srcimg.pixels[j * srcimg.width + i]);
  try {
    /* this is all from Java 6
     JPEGImageEncoder encoder = JPEGCodec.createJPEGEncoder(out);
     JPEGEncodeParam encpar = encoder.getDefaultJPEGEncodeParam(img);
     encpar.setQuality(1, false);
     encoder.setJPEGEncodeParam(encpar);
     encoder.encode(img);
     */
    ImageIO.write(img, "jpeg", out);
  }
  // why is an IOException thrown here?
  catch (Exception e) {
    System.out.println(e);
  }
  return out.toByteArray();
}

/*******************************************************************************
 * converts an array of frames 1RGB,2RGB...
 * into a new array of frames 1R,1G,1B,2R,2G,2B...
 */
PImage[] framesToRgb(PImage[] input) {
  println("Splitting frames to RGB...");
  PImage[] output = new PImage[input.length * 3];
  // assume all frames are the same size
  int width = input[0].width;
  int height = input[0].height;
  for (int i = 0; i < input.length; i++) {
    // we're only using one channel, so we'll save some space here
    PImage red = new PImage(width, height, ALPHA); 
    PImage green = new PImage(width, height, ALPHA);
    PImage blue = new PImage(width, height, ALPHA);

    for (int j = 0; j < width * height; j++) {
      int pixel = input[i].pixels[j];
      red.pixels[j] = pixel >> 16 & 0xFF;
      green.pixels[j] = pixel >> 8 & 0xFF;
      blue.pixels[j] = pixel & 0xFF;
    }
    output[i*3] = red;
    output[i*3+1] = green;
    output[i*3+2] = blue;
  }
  return output;
}

/*******************************************************************************
 * converts an array of frames 1R,1G,1B,2R,2G,2B...
 * into a new array of frames 1RGB,2RGB...
 */
PImage[] rgbToFrames(PImage[] input) {
  println("Merging RGB frames...");
  PImage[] output = new PImage[input.length / 3];
  // assume all frames are the same size
  int width = input[0].width;
  int height = input[0].height;
  for (int i = 0; i < input.length; i += 3) {
    PImage frame = new PImage(width, height);

    for (int j = 0; j < width * height; j++) {
      int pixel = (input[i].pixels[j] << 16 |
        input[i+1].pixels[j] << 8 |
        input[i+2].pixels[j]);

      frame.pixels[j] = pixel;
    }
    output[i/3] = frame;
  }
  return output;
}

/*******************************************************************************
 * moves random blocks of random frames around
 */
PImage[] glitchFrames(PImage[] frames, int glitchPercent, int maxGlitches, 
int maxGlitchSize, int maxGlitchDistance) {
  println("Glitching frames (block moving)... ");

  // assume all frames are the same size
  int width = frames[0].width;
  int height = frames[0].height;

  // glitch a certain number of frames
  int glitchedFrames = round(frames.length * glitchPercent / 100);
  for (int i = 0; i < glitchedFrames; i++) {
    int frameNumber = random.nextInt(frames.length);

    // for this frame, do a random number of glitches
    for (int j = 0; j < random.nextInt (maxGlitches) + 1; j++) {
      // determine the size and positions of the blocks to swap
      int blockWidth = random.nextInt(maxGlitchSize) + 1;
      // prefer horizontal blocks
      int blockHeight = random.nextInt(maxGlitchSize / 4) + 1;

      int block1X = random.nextInt(width - blockWidth);
      int block1Y = random.nextInt(height - blockHeight);

      // are we offsetting past the block or behind it?
      int distance = random.nextInt(maxGlitchDistance);
      if (random.nextBoolean()) {
        distance += blockWidth;
      } else {
        distance *= -1;
      }
      int block2X = block1X + distance;

      // again, for Y
      distance = random.nextInt(maxGlitchDistance);
      if (random.nextBoolean()) {
        distance += blockHeight;
      } else {
        distance *= -1;
      }
      int block2Y = block1Y + distance;

      // make sure we're not going out of bounds
      if (block2X < 0) {
        block2X +=  blockWidth;
      } else if (block2X + blockWidth >= width) {
        block2X -= blockWidth;
      }
      if (block2Y < 0) {
        block2Y +=  blockHeight;
      } else if (block2Y + blockHeight >= height) {
        block2Y -= blockHeight;
      }

      // how are we doing out there?
      /*String debug = "[" + blockWidth + "x" + blockHeight + "]";
       debug += " (" + block1X + "," + block1Y + ") -> (" + block2X + ",";
       debug +=  + block2Y + ")";
       println(debug);*/

      // finally, do the swapping
      PImage block1 = frames[frameNumber].get(block1X, block1Y, blockWidth, 
      blockHeight);
      PImage block2 = frames[frameNumber].get(block2X, block2Y, blockWidth, 
      blockHeight);
      frames[frameNumber].set(block1X, block1Y, block2);
      frames[frameNumber].set(block2X, block2Y, block1);
    }
  }
  return frames;
}
// default settings
PImage[] glitchFrames(PImage[] frames, boolean isRgb) {
  int glitchPercent = 50;
  if (isRgb) {
    glitchPercent /= 3;
  }
  // last three are number, size, distance
  return glitchFrames(frames, glitchPercent, 10, 50, 25);
}

/*******************************************************************************
 * does jpeg-corruption (the #notepad trick") glitching on random frames
 */
PImage[] jpegGlitchFrames(PImage[] frames, int glitchPercent, int maxCuts, 
int maxCutLength) {
  println("Glitching frames (JPEG corruption)...");

  // glitch a certain number of frames
  int glitchedFrames = round(frames.length * glitchPercent / 100);
  for (int i = 0; i < glitchedFrames; i++) {
    int frameNumber = random.nextInt(frames.length);
    byte[] frameBytes = frameToJpegBytes(frames[frameNumber]);
    // we can't cut from an array, so convert it first
    ArrayList<Byte> editableBytes = new ArrayList<Byte>();
    for (byte b : frameBytes) {
      editableBytes.add(b);
    }
    // do each glitch
    for (int j = 0; j < random.nextInt (maxCuts) + 1; j++) {
      // assume the header is over by 512 bytes in
      int cutStart = random.nextInt(editableBytes.size() -
        (512 + maxCutLength)) + 512;
      for (int k = 1; k < random.nextInt (maxCutLength) + 1; k++) {
        editableBytes.remove(cutStart);
      }
    }
    // convert back to byte array
    frameBytes = new byte[editableBytes.size()];
    int l = 0;
    for (byte b : editableBytes) {
      frameBytes[l++] = b;
    }
    frames[frameNumber] = jpegBytesToFrame(frameBytes);
  }
  return frames;
}
// default settings
PImage[] jpegGlitchFrames(PImage[] frames, boolean isRgb) {
  int glitchPercent = 20;
  if (isRgb) {
    glitchPercent /= 3;
  }
  // last two are max number of cuts, and max cut length
  return jpegGlitchFrames(frames, glitchPercent, 4, 10);
}

/*******************************************************************************
 * shuffles channels between adjacent frames
 */
PImage[] shuffleRgbFrames(PImage[] frames, int shufflePercent, 
int maxShuffleDistance) {
  println("Shuffling RGB frames...");
  int frameCount = frames.length / 3;
  int shuffles = round(frameCount * shufflePercent / 100);
  for (int i = 0; i < shuffles; i++) {
    // get the numbers of the frames being swapped between, and the channel
    // being swapped
    int frameNumber = random.nextInt(frameCount);
    int skipAmount = random.nextInt(maxShuffleDistance) + 1;
    if (random.nextBoolean()) {
      skipAmount *= -1;
    }
    int swapFrameNumber = frameNumber + skipAmount;
    if (swapFrameNumber >= frameCount) {
      swapFrameNumber -= frameCount;
    } else if (swapFrameNumber < 0) {
      swapFrameNumber += frameCount;
    }
    int channel = random.nextInt(3);
    // now we can swap
    PImage temp = frames[frameNumber * 3 + channel];
    frames[frameNumber * 3 + channel] = frames[swapFrameNumber * 3 + channel];
    frames[swapFrameNumber * 3 + channel] = temp;
  }
  return frames;
}
// default settings
PImage[] shuffleRgbFrames(PImage[] frames) {
  return shuffleRgbFrames(frames, 40, 2);
}

/*******************************************************************************
 * setup
 */
void setup() {
  // all processing
  PImage[] initialFrames = loadGifToFrames(inputFilename);
  if (initialFrames != null) {
    initialFrames = glitchFrames(initialFrames, false);
    PImage[] rgbFrames = framesToRgb(initialFrames);
    rgbFrames = shuffleRgbFrames(rgbFrames);
    rgbFrames = glitchFrames(rgbFrames, true);
    rgbFrames = jpegGlitchFrames(rgbFrames, true);
    displayFrames = rgbToFrames(rgbFrames);

    // set some things for the display
    frameRate(fps);
    size(displayFrames[0].width, displayFrames[0].height);
    //size(displayFrames[0].width + 10, displayFrames[0].height + 10);

    // set up the GIF encoder
    gifExport = new GifMaker(this, outputFilename);
    gifExport.setRepeat(0);
    println("\nPress any key to save a GIF.");
  } else {
    exit();
  }
}

/*******************************************************************************
 * drawing
 */
void draw() {
  // draw a black border around image if we've gone through all frames once
  /*if (!gifEncodingDone && !gifEncodingStarted) {
   background(0, 0, 0);
   } else if (gifEncodingStarted) {
   background(255, 255, 0);
   } else {
   background(0, 255, 0);
   }
   image(displayFrames[currentFrame], 5, 5);*/
  image(displayFrames[currentFrame], 0, 0);
  currentFrame++;
  if (currentFrame >= displayFrames.length) {
    currentFrame = 0;
    // GIF encoding is done!
    if (gifEncodingStarted) {
      gifExport.finish();
      gifEncodingDone = true;
      gifEncodingStarted = false;
      println("GIF saved!");
    }
    // start the GIF encoding on a new loop
    else if (gifEncodingWanted) {
      gifEncodingWanted = false;
      gifEncodingStarted = true;
      println("GIF creation started.");
    }
  }
  // add frames to gif  
  else if (gifEncodingStarted) {
    gifExport.setDelay(delay);
    gifExport.addFrame();
  }
}

void keyPressed() {
  if (!gifEncodingStarted && !gifEncodingDone) {
    gifEncodingWanted = true;
    println("GIF creation queued.");
  }
}

