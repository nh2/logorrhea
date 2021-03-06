import Control.Monad
import Control.Monad.Trans
import Network
import System.IO
import System.Environment

import IRC

server   = "irc.freenode.org"
port     = fromIntegral 6667
chan     = "#testlogo"
userName = "maaantrh5rhguyr"

connectToServer :: String -> PortNumber -> IO IRCInfo
connectToServer server port = do
    h <- connectTo server (PortNumber port)
    hSetBuffering h (BlockBuffering Nothing)
    return IRCInfo { ircHandle = h
                   , ircName   = server
                   , ircPort   = port
                   }
    
withConnection :: UserName -> IO IRCInfo -> IRCT IO () -> IO ()
withConnection un conn act = do
    i <- conn
    runIRCT un i $ do
        sendMessage $ nick un
        sendMessage $ user un "*" "*" un
        act
        sendMessage $ quit Nothing
        return ()

test_connectJoin :: IRCT IO ()
test_connectJoin = do
    sendMessage $ joinChan chan
    forever $ popMessage >>= liftIO . print

test_connectJoinMsg :: IRCT IO ()
test_connectJoinMsg = do
    sendMessage $ joinChan chan
    sendMessage $ privmsg chan "hello!"
    sendMessage $ part chan
    forever $ popMessage >>= liftIO . print
    
main :: IO ()
main = do
    args <- getArgs
    let un = case args of
            [s] -> s
            _   -> userName
        conn = connectToServer server port
    withConnection un conn test_connectJoin
    -- withConnection un conn test_connectJoinMsg
