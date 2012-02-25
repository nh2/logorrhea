{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module IRC 
    ( IRCInfo (..)
    , MonadIRC (..)
    , IRCT
    , runIRCT
      
    , module Network.IRC.Base
    , module Network.IRC.Commands
    ) where

import Control.Monad.Reader
import Control.Monad.State
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as B8
import Network
import Network.IRC.Base
import Network.IRC.Commands
import System.IO

import ParseMessage 

data IRCInfo = IRCInfo
    { ircHandle :: Handle 
    , ircName   :: String
    , ircPort   :: PortNumber
    }

class MonadIRC m where
    popMessage  :: m Message
    sendMessage :: Message -> m ()
    getUserName :: m UserName

newtype IRCT m a = IRCT {unIRC :: ReaderT IRCInfo (StateT UserName m) a}
    deriving (Functor, Monad, MonadIO)

instance MonadTrans IRCT where
    lift = IRCT . lift . lift

runIRCT :: MonadIO m => UserName -> IRCInfo -> IRCT m () -> m ()
runIRCT un i (IRCT act) = evalStateT (runReaderT act i) un

instance MonadIO m => MonadIRC (IRCT m) where
    popMessage = IRCT $ do
        h <- asks ircHandle
        Just msg <- liftM decode $ liftIO $ B.hGetLine h
        return msg
    
    sendMessage msg = do
        h <- IRCT $ asks ircHandle
        let bs = B8.pack . (++"\r\n") . encode $ msg
        liftIO $ B.putStr bs
        liftIO (B.hPut h bs >> hFlush h)
        
    getUserName = IRCT . lift $ get
