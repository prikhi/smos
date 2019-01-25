{-# LANGUAGE DeriveGeneric #-}

module Smos.Cursor.Properties
    ( PropertiesCursor(..)
    , emptyPropertiesCursor
    , singletonPropertiesCursor
    , makePropertiesCursor
    , rebuildPropertiesCursor
    , propertiesCursorToggleSelected
    , propertiesCursorSelectNextChar
    , propertiesCursorSelectPrevChar
    , propertiesCursorSelectNextProperty
    , propertiesCursorSelectPrevProperty
    , propertiesCursorInsert
    , propertiesCursorAppend
    , propertiesCursorRemove
    , propertiesCursorDelete
    , propertiesCursorStartNewPropertyBefore
    , propertiesCursorStartNewPropertyAfter
    , propertiesCursorAddOrSelect
    , propertiesCursorSet
    ) where

import GHC.Generics (Generic)

import Control.Monad
import Data.List.NonEmpty (NonEmpty(..))
import Data.Maybe
import Data.Validity

import Lens.Micro

import Cursor.List.NonEmpty
import Cursor.Map
import Cursor.Text
import Cursor.Types

import Smos.Data.Types

newtype PropertiesCursor = PropertiesCursor
    { propertiesCursorMapCursor :: MapCursor TextCursor TextCursor PropertyName PropertyValue
    } deriving (Show, Eq, Generic)

instance Validity PropertiesCursor where
    validate (PropertiesCursor pc) =
        mconcat
            [ delve "propertiesCursorMapCursor" pc
            , declare "The text cursor under selection builds to a valid value" $
              case nonEmptyCursorCurrent (mapCursorList pc) of
                  KeyValueCursorKey tc _ ->
                      isJust $ propertyName $ rebuildTextCursor tc
                  KeyValueCursorValue _ tc ->
                      isJust $ propertyValue $ rebuildTextCursor tc
            ]

propertiesCursorMapCursorL ::
       Lens' PropertiesCursor (MapCursor TextCursor TextCursor PropertyName PropertyValue)
propertiesCursorMapCursorL =
    lens propertiesCursorMapCursor $ \pc mc ->
        pc {propertiesCursorMapCursor = mc}

emptyPropertiesCursor :: PropertiesCursor
emptyPropertiesCursor =
    singletonPropertiesCursor emptyPropertyName emptyPropertyValue

singletonPropertiesCursor :: PropertyName -> PropertyValue -> PropertiesCursor
singletonPropertiesCursor pn pv = makePropertiesCursor $ (pn, pv) :| []

makePropertiesCursor ::
       NonEmpty (PropertyName, PropertyValue) -> PropertiesCursor
makePropertiesCursor = PropertiesCursor . makeMapCursor makePropertyNameCursor

rebuildPropertiesCursor ::
       PropertiesCursor -> NonEmpty (PropertyName, PropertyValue)
rebuildPropertiesCursor =
    rebuildMapCursor rebuildPropertyNameCursor rebuildPropertyValueCursor .
    propertiesCursorMapCursor

propertiesCursorCurrentTextCursorL :: Lens' PropertiesCursor TextCursor
propertiesCursorCurrentTextCursorL =
    propertiesCursorMapCursorL .
    lens
        (\tsc ->
             case tsc ^. mapCursorElemL of
                 KeyValueCursorKey kc _ -> kc
                 KeyValueCursorValue _ vc -> vc)
        (\tsc tc ->
             tsc & mapCursorElemL %~
             (\kvc ->
                  case kvc of
                      KeyValueCursorKey _ v -> KeyValueCursorKey tc v
                      KeyValueCursorValue k _ -> KeyValueCursorValue k tc))

propertiesCursorToggleSelected :: PropertiesCursor -> PropertiesCursor
propertiesCursorToggleSelected =
    propertiesCursorMapCursorL %~
    mapCursorToggleSelected
        rebuildPropertyNameCursor
        makePropertyNameCursor
        rebuildPropertyValueCursor
        makePropertyValueCursor

propertiesCursorSelectNextChar :: PropertiesCursor -> Maybe PropertiesCursor
propertiesCursorSelectNextChar =
    propertiesCursorCurrentTextCursorL $ textCursorSelectNext

propertiesCursorSelectPrevChar :: PropertiesCursor -> Maybe PropertiesCursor
propertiesCursorSelectPrevChar =
    propertiesCursorCurrentTextCursorL $ textCursorSelectPrev

propertiesCursorSelectNextProperty :: PropertiesCursor -> Maybe PropertiesCursor
propertiesCursorSelectNextProperty =
    propertiesCursorMapCursorL $
    mapCursorSelectNext
        rebuildPropertyNameCursor
        makePropertyNameCursor
        rebuildPropertyValueCursor

propertiesCursorSelectPrevProperty :: PropertiesCursor -> Maybe PropertiesCursor
propertiesCursorSelectPrevProperty =
    propertiesCursorMapCursorL $
    mapCursorSelectPrev
        rebuildPropertyNameCursor
        makePropertyNameCursor
        rebuildPropertyValueCursor

propertiesCursorInsert :: Char -> PropertiesCursor -> Maybe PropertiesCursor
propertiesCursorInsert c =
    propertiesCursorCurrentTextCursorL (textCursorInsert c) >=> constructValid

propertiesCursorAppend :: Char -> PropertiesCursor -> Maybe PropertiesCursor
propertiesCursorAppend c =
    propertiesCursorCurrentTextCursorL (textCursorAppend c) >=> constructValid

propertiesCursorRemove ::
       PropertiesCursor -> Maybe (DeleteOrUpdate PropertiesCursor)
propertiesCursorRemove =
    focusPossibleDeleteOrUpdate
        propertiesCursorCurrentTextCursorL
        textCursorRemove

propertiesCursorDelete ::
       PropertiesCursor -> Maybe (DeleteOrUpdate PropertiesCursor)
propertiesCursorDelete =
    focusPossibleDeleteOrUpdate
        propertiesCursorCurrentTextCursorL
        textCursorDelete

propertiesCursorStartNewPropertyBefore :: PropertiesCursor -> PropertiesCursor
propertiesCursorStartNewPropertyBefore =
    propertiesCursorMapCursorL %~
    mapCursorInsertAndSelectKey
        rebuildPropertyNameCursor
        rebuildPropertyValueCursor
        emptyTextCursor
        emptyPropertyValue

propertiesCursorStartNewPropertyAfter :: PropertiesCursor -> PropertiesCursor
propertiesCursorStartNewPropertyAfter =
    propertiesCursorMapCursorL %~
    mapCursorAppendAndSelectKey
        rebuildPropertyNameCursor
        rebuildPropertyValueCursor
        emptyTextCursor
        emptyPropertyValue

propertiesCursorAddOrSelect ::
       PropertyName -> Maybe PropertiesCursor -> PropertiesCursor
propertiesCursorAddOrSelect pn mpc =
    let pc = fromMaybe (singletonPropertiesCursor pn emptyPropertyValue) mpc
    in case propertiesCursorMapCursorL
                (mapCursorSearch
                     rebuildPropertyNameCursor
                     makePropertyNameCursor
                     rebuildPropertyValueCursor
                     (\k _ -> k == pn))
                pc of
           Just pc' ->
               pc' & propertiesCursorMapCursorL %~
               mapCursorSelectValue
                   rebuildPropertyNameCursor
                   makePropertyValueCursor
           Nothing ->
               pc & propertiesCursorMapCursorL %~
               mapCursorInsertAndSelectValue
                   rebuildPropertyNameCursor
                   rebuildPropertyValueCursor
                   pn
                   emptyTextCursor

propertiesCursorSet ::
       PropertyName
    -> PropertyValue
    -> Maybe PropertiesCursor
    -> PropertiesCursor
propertiesCursorSet pn pv mpc =
    case mpc of
        Nothing -> singletonPropertiesCursor pn pv
        Just pc ->
            case pc &
                 propertiesCursorMapCursorL
                     (mapCursorSearch
                          rebuildPropertyNameCursor
                          makePropertyNameCursor
                          rebuildPropertyValueCursor
                          (\k _ -> k == pn)) of
                Just pc' ->
                    pc' & (propertiesCursorMapCursorL . mapCursorElemL) %~
                    (\kvc ->
                         case kvc of
                             KeyValueCursorKey tc _ ->
                                 KeyValueCursorValue
                                     (rebuildPropertyNameCursor tc)
                                     (makePropertyValueCursor pv)
                             KeyValueCursorValue k _ ->
                                 KeyValueCursorValue
                                     k
                                     (makePropertyValueCursor pv))
                Nothing ->
                    pc & propertiesCursorMapCursorL %~
                    mapCursorAppendAndSelectValue
                        rebuildPropertyNameCursor
                        rebuildPropertyValueCursor
                        pn
                        (makePropertyValueCursor pv)

-- safe because of validity
rebuildPropertyNameCursor :: TextCursor -> PropertyName
rebuildPropertyNameCursor = fromJust . propertyName . rebuildTextCursor

-- safe because of validity
rebuildPropertyValueCursor :: TextCursor -> PropertyValue
rebuildPropertyValueCursor = fromJust . propertyValue . rebuildTextCursor

makePropertyNameCursor :: PropertyName -> TextCursor
makePropertyNameCursor = fromJust . makeTextCursor . propertyNameText

makePropertyValueCursor :: PropertyValue -> TextCursor
makePropertyValueCursor = fromJust . makeTextCursor . propertyValueText
