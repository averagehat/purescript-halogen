module Halogen.Query.HalogenF
  ( HalogenFP(..)
  , HalogenF()
  , transformHF
  , hoistHalogenF
  ) where

import Prelude

import Control.Alt (Alt)
import Control.Monad.Aff.Free (Affable, fromAff)
import Control.Monad.Free.Trans (hoistFreeT, bimapFreeT)
import Control.Plus (Plus)

import Data.Bifunctor (lmap)
import Data.NaturalTransformation (Natural())

import Halogen.Query.EventSource (EventSource(..), runEventSource)
import Halogen.Query.StateF (StateF())

-- | The Halogen component algebra
data HalogenFP (e :: (* -> *) -> (* -> *) -> *) s f g a
  = StateHF (StateF s a)
  | SubscribeHF (e f g) a
  | QueryHF (g a)
  | HaltHF

type HalogenF = HalogenFP EventSource

instance functorHalogenF :: (Functor g) => Functor (HalogenFP e s f g) where
  map f h =
    case h of
      StateHF q -> StateHF (map f q)
      SubscribeHF es a -> SubscribeHF es (f a)
      QueryHF q -> QueryHF (map f q)
      HaltHF -> HaltHF

instance affableHalogenF :: (Affable eff g) => Affable eff (HalogenFP e s f g) where
  fromAff = QueryHF <<< fromAff

instance altHalogenF :: (Functor g) => Alt (HalogenFP e s f g) where
  alt HaltHF h = h
  alt h _ = h

instance plusHalogenF :: (Functor g) => Plus (HalogenFP e s f g) where
  empty = HaltHF

-- | Change all the parameters of `HalogenF`.
transformHF
  :: forall s s' f f' g g'
   . (Functor g')
  => Natural (StateF s) (StateF s')
  -> Natural f f'
  -> Natural g g'
  -> Natural (HalogenF s f g) (HalogenF s' f' g')
transformHF sigma phi gamma h =
  case h of
    StateHF q -> StateHF (sigma q)
    SubscribeHF es next -> SubscribeHF (EventSource (bimapFreeT (lmap phi) gamma (runEventSource es))) next
    QueryHF q -> QueryHF (gamma q)
    HaltHF -> HaltHF

-- | Changes the `g` for a `HalogenF`. Used internally by Halogen.
hoistHalogenF
  :: forall s f g h
   . (Functor h)
  => Natural g h
  -> Natural (HalogenF s f g) (HalogenF s f h)
hoistHalogenF eta h =
  case h of
    StateHF q -> StateHF q
    SubscribeHF es next -> SubscribeHF (EventSource (hoistFreeT eta (runEventSource es))) next
    QueryHF q -> QueryHF (eta q)
    HaltHF -> HaltHF
