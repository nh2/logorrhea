module DrLogos.Parser
       ( BotMessage(..)
       , UserCommand(..)
       , unParse
       , p_botMessage
       , p_userCommand
       , u_botMessage
       , u_userCommand
       ) where

import Control.Applicative
import Text.Parsec hiding (many)
import Text.Parsec.String

import IRC

data BotMessage
    = UserMessage NickName Tag String
    | NoQuestions Tag
    | NotAQuestion Channel
    | QuestionMessage NickName String
    deriving (Show)

data UserCommand
    = NewQuestion (Maybe Tag) String
    | ListQuestions
    | History
    deriving (Show)

sp :: Parser a -> Parser a
sp p = p <* space <* spaces

p_startCommand :: String -> Parser ()
p_startCommand cmd = string "??" >> string cmd >> return ()

p_userCommand :: Parser UserCommand
p_userCommand = choice . map try $
                [ p_newQuestion
                , p_listQuestions 
                , p_history
                ]
  where
    p_newQuestion =
        NewQuestion
            <$> (sp (p_startCommand "new") >> optionMaybe p_tag)
            <*> (manyTill anyChar eof)
    p_listQuestions =
        p_startCommand "list" >> spaces >> eof >> return ListQuestions
    p_history = p_startCommand "hist" >> spaces >> eof >> return History

p_botMessage :: Parser BotMessage
p_botMessage = choice . map try $
               [ p_userMessage
               , p_noQuestions
               , p_notAQuestion
               , p_questionMessage
               ]

p_userMessage :: Parser BotMessage
p_userMessage = UserMessage
             <$> (sp p_nickName <* sp (string "@"))
             <*> (sp p_tag <* string ": ") 
             <*> manyTill anyChar eof

p_noQuestions :: Parser BotMessage
p_noQuestions = NoQuestions <$> (string "No questions in " >> p_tag)

p_notAQuestion :: Parser BotMessage
p_notAQuestion = NotAQuestion <$>
                 (string "The channel " *> p_tag <* string" is not a question")

p_questionMessage :: Parser BotMessage
p_questionMessage = QuestionMessage
                        <$> (char '<' *> p_nickName <* char '>')
                        <*> (space *> many anyChar <* eof)

p_nickName :: Parser NickName
p_nickName = (:) <$> letter <*> many alphaNum

p_tag :: Parser String
p_tag = (:) <$> char '#' <*> ((:) <$> letter <*> many alphaNum)

type UnParser a = a -> String -> String

unParse :: UnParser a -> a -> String
unParse up a = up a []

u_sp :: UnParser a -> UnParser a
u_sp u s = (u_string " " . u s)

u_string :: UnParser String
u_string = (++)

u_botMessage :: UnParser BotMessage
u_botMessage (UserMessage n t s) = foldl (.) id . map u_string $  
                                   [n, " @ ", t, " : ", s]
u_botMessage (NoQuestions t) = u_string $ "No questions in " ++ t
u_botMessage (NotAQuestion ch) = u_string $ "The channel " ++ ch ++
                                 " is not a question"
u_botMessage (QuestionMessage nn body) = u_string $ "<" ++ nn ++ "> " ++ body

u_startCommand :: UnParser String
u_startCommand cmd = u_string "??" . u_string cmd

u_maybe :: UnParser a -> UnParser (Maybe a)
u_maybe up m = maybe id up m

u_userCommand :: UnParser UserCommand
u_userCommand ListQuestions = u_startCommand "list"
u_userCommand (NewQuestion mTag body) =
    u_startCommand "new"
    . u_string " "
    . u_maybe u_string mTag
    . u_string " "
    . u_string body
u_userCommand History = u_startCommand "hist"
