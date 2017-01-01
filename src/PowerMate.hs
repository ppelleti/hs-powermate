{-# LANGUAGE MultiWayIf #-}

module PowerMate
  ( Knob
  , Event (..)
  , openController
  , nextEvent
  , setLed
  , closeController
  ) where

import Data.Word
import Foreign.Marshal.Alloc
import Foreign.Marshal.Utils
import Foreign.Storable
import System.IO

import PowerMate.Foreign

newtype Knob = Knob Handle

data Event = ButtonPressed | ButtonReleased | Clockwise | Counterclockwise
           deriving (Eq, Ord, Show, Read, Bounded, Enum)

powermateDevice :: String
powermateDevice = "/dev/input/powermate"

openController :: IO Knob
openController = do
  h <- openFile powermateDevice ReadWriteMode
  hSetBuffering h NoBuffering
  return $ Knob h

nextEvent :: Knob -> IO Event
nextEvent k@(Knob h) = do
  ie <- readEvent h
  let et = eventType ie
      ec = eventCode ie
      ev = eventValue ie
  if | et == evKey && ev == 1    -> return ButtonPressed
     | et == evKey && ev == 0    -> return ButtonReleased
     | et == evRel && ev == 1    -> return Clockwise
     | et == evRel && ev == (-1) -> return Counterclockwise
     | otherwise                 -> nextEvent k

setLed :: Knob -> Word8 -> IO ()
setLed (Knob h) v = do
  writeEvent h $ InputEvent 0 0 evMsc mscPulseLed $ fromIntegral v

closeController :: Knob -> IO ()
closeController (Knob h) = hClose h

readEvent :: Handle -> IO InputEvent
readEvent h = alloca $ \p -> do
  let sz = sizeOf (undefined :: InputEvent)
  ret <- hGetBuf h p sz
  if ret == sz
    then peek p
    else fail ("end-of-file on " ++ powermateDevice)

writeEvent :: Handle -> InputEvent -> IO ()
writeEvent h ie = with ie $ \p -> hPutBuf h p (sizeOf ie)
