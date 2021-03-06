{-# LANGUAGE TypeApplications #-}

module Smos.Cursor.LogbookSpec where

import Smos.Cursor.Logbook
import Smos.Cursor.Logbook.Gen ()
import Smos.Data.Gen ()
import Test.Hspec
import Test.Validity

spec :: Spec
spec = do
  eqSpec @LogbookCursor
  genValidSpec @LogbookCursor
  describe "makeLogbookCursor"
    $ it "produces valid cursors"
    $ producesValidsOnValids makeLogbookCursor
  describe "rebuildLogbookCursor" $ do
    it "produces valid cursors" $ producesValidsOnValids rebuildLogbookCursor
    it "is the inverse of makeLogbookCursor" $
      inverseFunctionsOnValid makeLogbookCursor rebuildLogbookCursor
  describe "logbookCursorClockIn"
    $ it "produces valid cursors"
    $ producesValidsOnValids2 logbookCursorClockIn
  describe "logbookCursorClockOut"
    $ it "produces valid cursors"
    $ producesValidsOnValids2 logbookCursorClockOut
