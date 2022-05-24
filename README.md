# Instructions
Once you completed the contract `contracts/Battleships.sol`, you can run `docker build -t battleships .` to build the battleships docker image.

Prerequisite: please [install docker](https://docs.docker.com/desktop/) on your system.

For WSL run

`sudo dockerd`

To set up and play your battleships game, you can:

1. start the ganache test chain

`docker run -p 8545:8545 -d trufflesuite/ganache-cli:latest -g 0`

2. start the web server

`docker run -p 8080:8080 -d battleships`

3. open `http://localhost:8080/` in two separate web browsers with each a separate Metamask installed, and enjoy the game. On Chrome you can create **two different users** and install Metamask in each. You'll need to configure Metamask to connect to your local chain as well.

