pragma solidity ^0.4.21;


import "./owned.sol";
import "./FixedSupplyToken.sol";


contract Exchange is owned {

    struct Offer {
        uint amount;
        address who;
    }

    struct OrderBook {
        uint higherPrice;
        uint lowerPrice;
        mapping (uint => Offer) offers;
        uint offers_key;
        uint offers_length;
    }

    struct Token {
        address tokenContract;
        string symbolName;
        mapping (uint => OrderBook) buyBook;
        uint curBuyPrice;
        uint lowestBuyPrice;
        uint amountBuyPrices;
        mapping (uint => OrderBook) sellBook;
        uint curSellPrice;
        uint highestSellPrice;
        uint amountSellPrices;
    }

    mapping (uint8 => Token) tokens;
    uint8 tokenIndex;
    
    mapping (address => mapping (uint8 => uint)) tokenBalanceForAddress;

    mapping (address => uint) balanceEthForAddress;

    event DepositForTokenReceived(address indexed _from, uint indexed _symbolIndex, uint _amount, uint _timestamp);

    event WithdrawalToken(address indexed _to, uint indexed _symbolIndex, uint _amount, uint _timestamp);

    event DepositForEthReceived(address indexed _from, uint _amount, uint _timestamp);

    event WithdrawalEth(address indexed _to, uint _amount, uint _timestamp);

    event LimitSellOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);

    event SellOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);

    event SellOrderCanceled(uint indexed _symbolIndex, uint _priceInWei, uint _orderKey);

    event LimitBuyOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);

    event BuyOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);

    event BuyOrderCanceled(uint indexed _symbolIndex, uint _priceInWei, uint _orderKey);

    event TokenAddedToSystem(uint _symbolIndex, string _token, uint _timestamp);

    function depositEther() public payable {
        require(balanceEthForAddress[msg.sender] + msg.value >= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] += msg.value;
        emit DepositForEthReceived(msg.sender, msg.value, now);
    }

    function withdrawEther(uint amountInWei) public {
        require(balanceEthForAddress[msg.sender] - amountInWei >= 0);
        require(balanceEthForAddress[msg.sender] - amountInWei <= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] -= amountInWei;
        msg.sender.transfer(amountInWei);
        emit WithdrawalEth(msg.sender, amountInWei, now);
    }

    function getEthBalanceInWei() view public returns (uint){
        return balanceEthForAddress[msg.sender];
    }

    function addToken(string symbolName, address erc20TokenAddress) public onlyowner {
        require(!hasToken(symbolName));
        require(tokenIndex + 1 > tokenIndex);
        tokenIndex++;

        tokens[tokenIndex].symbolName = symbolName;
        tokens[tokenIndex].tokenContract = erc20TokenAddress;
        emit TokenAddedToSystem(tokenIndex, symbolName, now);
    }

    function hasToken(string symbolName) view public returns (bool) {
        uint8 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return false;
        }
        return true;
    }

    function getSymbolIndex(string symbolName) internal view returns (uint8) {
        for (uint8 i = 1; i <= tokenIndex; i++) {
            if (stringsEqual(tokens[i].symbolName, symbolName)) {
                return i;
            }
        }
        return 0;
    }

    function getSymbolIndexOrThrow(string symbolName) public view returns (uint8) {
        uint8 index = getSymbolIndex(symbolName);
        require(index > 0);
        return index;
    }

    function depositToken(string symbolName, uint amount) public {
        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndex].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[symbolNameIndex].tokenContract);

        require(token.transferFrom(msg.sender, address(this), amount) == true);
        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] + amount >= tokenBalanceForAddress[msg.sender][symbolNameIndex]);
        tokenBalanceForAddress[msg.sender][symbolNameIndex] += amount;
        emit DepositForTokenReceived(msg.sender, symbolNameIndex, amount, now);
    }

    function withdrawToken(string symbolName, uint amount) public {
        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndex].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[symbolNameIndex].tokenContract);

        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] - amount >= 0);
        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] - amount <= tokenBalanceForAddress[msg.sender][symbolNameIndex]);

        tokenBalanceForAddress[msg.sender][symbolNameIndex] -= amount;
        require(token.transfer(msg.sender, amount) == true);
        emit WithdrawalToken(msg.sender, symbolNameIndex, amount, now);
    }

    function getBalance(string symbolName) view public returns (uint) {
        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        return tokenBalanceForAddress[msg.sender][symbolNameIndex];
    }

    function getBuyOrderBook(string symbolName) view public returns (uint[], uint[]) {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint[] memory arrPricesBuy = new uint[](tokens[tokenNameIndex].amountBuyPrices);
        uint[] memory arrVolumesBuy = new uint[](tokens[tokenNameIndex].amountBuyPrices);

        uint whilePrice = tokens[tokenNameIndex].lowestBuyPrice;
        uint counter = 0;
        if (tokens[tokenNameIndex].curBuyPrice > 0) {
            while (whilePrice <= tokens[tokenNameIndex].curBuyPrice) {
                arrPricesBuy[counter] = whilePrice;
                uint volumeAtPrice = 0;
                uint offers_key = 0;

                offers_key = tokens[tokenNameIndex].buyBook[whilePrice].offers_key;
                while (offers_key <= tokens[tokenNameIndex].buyBook[whilePrice].offers_length) {
                    volumeAtPrice += tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].amount;
                    offers_key++;
                }

                arrVolumesBuy[counter] = volumeAtPrice;

                if (whilePrice == tokens[tokenNameIndex].buyBook[whilePrice].higherPrice) {
                    break;
                }
                else {
                    whilePrice = tokens[tokenNameIndex].buyBook[whilePrice].higherPrice;
                }
                counter++;

            }
        }
        return (arrPricesBuy, arrVolumesBuy);
    }
    
    function getSellOrderBook(string symbolName) view public returns (uint[], uint[]) {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint[] memory arrPricesSell = new uint[](tokens[tokenNameIndex].amountSellPrices);
        uint[] memory arrVolumesSell = new uint[](tokens[tokenNameIndex].amountSellPrices);
        uint sellWhilePrice = tokens[tokenNameIndex].curSellPrice;
        uint sellCounter = 0;
        if (tokens[tokenNameIndex].curSellPrice > 0) {
            while (sellWhilePrice <= tokens[tokenNameIndex].highestSellPrice) {
                arrPricesSell[sellCounter] = sellWhilePrice;
                uint sellVolumeAtPrice = 0;
                uint sell_offers_key = 0;

                sell_offers_key = tokens[tokenNameIndex].sellBook[sellWhilePrice].offers_key;
                while (sell_offers_key <= tokens[tokenNameIndex].sellBook[sellWhilePrice].offers_length) {
                    sellVolumeAtPrice += tokens[tokenNameIndex].sellBook[sellWhilePrice].offers[sell_offers_key].amount;
                    sell_offers_key++;
                }

                arrVolumesSell[sellCounter] = sellVolumeAtPrice;

                //next whilePrice
                if (tokens[tokenNameIndex].sellBook[sellWhilePrice].higherPrice == 0) {
                    break;
                }
                else {
                    sellWhilePrice = tokens[tokenNameIndex].sellBook[sellWhilePrice].higherPrice;
                }
                sellCounter++;

            }
        }
        return (arrPricesSell, arrVolumesSell);
    }
    
    function buyToken(string symbolName, uint priceInWei, uint amount) public {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint total_amount_ether_necessary = 0;

        if (tokens[tokenNameIndex].amountSellPrices == 0 || tokens[tokenNameIndex].curSellPrice > priceInWei) {
            total_amount_ether_necessary = amount * priceInWei;

            require(total_amount_ether_necessary >= amount);
            require(total_amount_ether_necessary >= priceInWei);
            require(balanceEthForAddress[msg.sender] >= total_amount_ether_necessary);
            require(balanceEthForAddress[msg.sender] - total_amount_ether_necessary >= 0);
            require(balanceEthForAddress[msg.sender] - total_amount_ether_necessary <= balanceEthForAddress[msg.sender]);

            balanceEthForAddress[msg.sender] -= total_amount_ether_necessary;

            addBuyOffer(tokenNameIndex, priceInWei, amount, msg.sender);
            emit LimitBuyOrderCreated(tokenNameIndex, msg.sender, amount, priceInWei, tokens[tokenNameIndex].buyBook[priceInWei].offers_length);
        }
        else {
            uint total_amount_ether_available = 0;
            uint whilePrice = tokens[tokenNameIndex].curSellPrice;
            uint amountNecessary = amount;
            uint offers_key;
            while (whilePrice <= priceInWei && amountNecessary > 0) {//we start with the smallest sell price.
                offers_key = tokens[tokenNameIndex].sellBook[whilePrice].offers_key;
                while (offers_key <= tokens[tokenNameIndex].sellBook[whilePrice].offers_length && amountNecessary > 0) {//and the first order (FIFO)
                    uint volumeAtPriceFromAddress = tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].amount;
                    if (volumeAtPriceFromAddress <= amountNecessary) {
                        total_amount_ether_available = volumeAtPriceFromAddress * whilePrice;

                        require(balanceEthForAddress[msg.sender] >= total_amount_ether_available);
                        require(balanceEthForAddress[msg.sender] - total_amount_ether_available <= balanceEthForAddress[msg.sender]);
                        balanceEthForAddress[msg.sender] -= total_amount_ether_available;

                        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] + volumeAtPriceFromAddress >= tokenBalanceForAddress[msg.sender][tokenNameIndex]);
                        require(balanceEthForAddress[tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].who] + total_amount_ether_available >= balanceEthForAddress[tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].who]);
                        tokenBalanceForAddress[msg.sender][tokenNameIndex] += volumeAtPriceFromAddress;
                        tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].amount = 0;
                        balanceEthForAddress[tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].who] += total_amount_ether_available;
                        tokens[tokenNameIndex].sellBook[whilePrice].offers_key++;

                        emit SellOrderFulfilled(tokenNameIndex, volumeAtPriceFromAddress, whilePrice, offers_key);

                        amountNecessary -= volumeAtPriceFromAddress;
                    }
                    else {
                        require(tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].amount > amountNecessary);//sanity

                        total_amount_ether_necessary = amountNecessary * whilePrice;
                        require(balanceEthForAddress[msg.sender] - total_amount_ether_necessary <= balanceEthForAddress[msg.sender]);

                        balanceEthForAddress[msg.sender] -= total_amount_ether_necessary;

                        require(balanceEthForAddress[tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].who] + total_amount_ether_necessary >= balanceEthForAddress[tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].who]);
                        tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].amount -= amountNecessary;
                        balanceEthForAddress[tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].who] += total_amount_ether_necessary;
                        tokenBalanceForAddress[msg.sender][tokenNameIndex] += amountNecessary;

                        amountNecessary = 0;
                        emit SellOrderFulfilled(tokenNameIndex, amountNecessary, whilePrice, offers_key);
                    }
                    if (
                    offers_key == tokens[tokenNameIndex].sellBook[whilePrice].offers_length &&
                    tokens[tokenNameIndex].sellBook[whilePrice].offers[offers_key].amount == 0
                    ) {

                        tokens[tokenNameIndex].amountSellPrices--;
                        if (whilePrice == tokens[tokenNameIndex].sellBook[whilePrice].higherPrice || tokens[tokenNameIndex].buyBook[whilePrice].higherPrice == 0) {
                            tokens[tokenNameIndex].curSellPrice = 0;
                        }
                        else {
                            tokens[tokenNameIndex].curSellPrice = tokens[tokenNameIndex].sellBook[whilePrice].higherPrice;
                            tokens[tokenNameIndex].sellBook[tokens[tokenNameIndex].buyBook[whilePrice].higherPrice].lowerPrice = 0;
                        }
                    }
                    offers_key++;
                }
                whilePrice = tokens[tokenNameIndex].curSellPrice;
            }

            if (amountNecessary > 0) {
                buyToken(symbolName, priceInWei, amountNecessary);
            }
        }
    }
    
    function addBuyOffer(uint8 _tokenIndex, uint priceInWei, uint amount, address who) internal {
        tokens[_tokenIndex].buyBook[priceInWei].offers_length++;
        tokens[_tokenIndex].buyBook[priceInWei].offers[tokens[_tokenIndex].buyBook[priceInWei].offers_length] = Offer(amount, who);


        if (tokens[_tokenIndex].buyBook[priceInWei].offers_length == 1) {
            tokens[_tokenIndex].buyBook[priceInWei].offers_key = 1;
            tokens[_tokenIndex].amountBuyPrices++;

            uint curBuyPrice = tokens[_tokenIndex].curBuyPrice;

            uint lowestBuyPrice = tokens[_tokenIndex].lowestBuyPrice;
            if (lowestBuyPrice == 0 || lowestBuyPrice > priceInWei) {
                if (curBuyPrice == 0) {
                    tokens[_tokenIndex].curBuyPrice = priceInWei;
                    tokens[_tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                    tokens[_tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                }
                else {
                    tokens[_tokenIndex].buyBook[lowestBuyPrice].lowerPrice = priceInWei;
                    tokens[_tokenIndex].buyBook[priceInWei].higherPrice = lowestBuyPrice;
                    tokens[_tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                }
                tokens[_tokenIndex].lowestBuyPrice = priceInWei;
            }
            else if (curBuyPrice < priceInWei) {
                tokens[_tokenIndex].buyBook[curBuyPrice].higherPrice = priceInWei;
                tokens[_tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                tokens[_tokenIndex].buyBook[priceInWei].lowerPrice = curBuyPrice;
                tokens[_tokenIndex].curBuyPrice = priceInWei;

            }
            else {

                uint buyPrice = tokens[_tokenIndex].curBuyPrice;
                bool weFoundIt = false;
                while (buyPrice > 0 && !weFoundIt) {
                    if (
                    buyPrice < priceInWei &&
                    tokens[_tokenIndex].buyBook[buyPrice].higherPrice > priceInWei
                    ) {
                        tokens[_tokenIndex].buyBook[priceInWei].lowerPrice = buyPrice;
                        tokens[_tokenIndex].buyBook[priceInWei].higherPrice = tokens[_tokenIndex].buyBook[buyPrice].higherPrice;

                        tokens[_tokenIndex].buyBook[tokens[_tokenIndex].buyBook[buyPrice].higherPrice].lowerPrice = priceInWei;
                        tokens[_tokenIndex].buyBook[buyPrice].higherPrice = priceInWei;

                        weFoundIt = true;
                    }
                    buyPrice = tokens[_tokenIndex].buyBook[buyPrice].lowerPrice;
                }
            }
        }
    }

    function sellToken(string symbolName, uint priceInWei, uint amount) public {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint total_amount_ether_necessary = 0;
        uint total_amount_ether_available = 0;


        if (tokens[tokenNameIndex].amountBuyPrices == 0 || tokens[tokenNameIndex].curBuyPrice < priceInWei) {

            total_amount_ether_necessary = amount * priceInWei;

            require(total_amount_ether_necessary >= amount);
            require(total_amount_ether_necessary >= priceInWei);
            require(tokenBalanceForAddress[msg.sender][tokenNameIndex] >= amount);
            require(tokenBalanceForAddress[msg.sender][tokenNameIndex] - amount >= 0);
            require(balanceEthForAddress[msg.sender] + total_amount_ether_necessary >= balanceEthForAddress[msg.sender]);

            tokenBalanceForAddress[msg.sender][tokenNameIndex] -= amount;

            addSellOffer(tokenNameIndex, priceInWei, amount, msg.sender);
            emit LimitSellOrderCreated(tokenNameIndex, msg.sender, amount, priceInWei, tokens[tokenNameIndex].sellBook[priceInWei].offers_length);

        }
        else {
            uint whilePrice = tokens[tokenNameIndex].curBuyPrice;
            uint amountNecessary = amount;
            uint offers_key;
            while (whilePrice >= priceInWei && amountNecessary > 0) {//we start with the highest buy price.
                offers_key = tokens[tokenNameIndex].buyBook[whilePrice].offers_key;
                while (offers_key <= tokens[tokenNameIndex].buyBook[whilePrice].offers_length && amountNecessary > 0) {//and the first order (FIFO)
                    uint volumeAtPriceFromAddress = tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].amount;

                    if (volumeAtPriceFromAddress <= amountNecessary) {
                        total_amount_ether_available = volumeAtPriceFromAddress * whilePrice;

                        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] >= volumeAtPriceFromAddress);
                        tokenBalanceForAddress[msg.sender][tokenNameIndex] -= volumeAtPriceFromAddress;

                        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] - volumeAtPriceFromAddress >= 0);
                        require(tokenBalanceForAddress[tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].who][tokenNameIndex] + volumeAtPriceFromAddress >= tokenBalanceForAddress[tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].who][tokenNameIndex]);
                        require(balanceEthForAddress[msg.sender] + total_amount_ether_available >= balanceEthForAddress[msg.sender]);

                        tokenBalanceForAddress[tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].who][tokenNameIndex] += volumeAtPriceFromAddress;
                        tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].amount = 0;
                        balanceEthForAddress[msg.sender] += total_amount_ether_available;
                        tokens[tokenNameIndex].buyBook[whilePrice].offers_key++;
                        emit SellOrderFulfilled(tokenNameIndex, volumeAtPriceFromAddress, whilePrice, offers_key);


                        amountNecessary -= volumeAtPriceFromAddress;
                    }
                    else {
                        require(volumeAtPriceFromAddress - amountNecessary > 0);
                        total_amount_ether_necessary = amountNecessary * whilePrice;
                        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] >= amountNecessary);
                        tokenBalanceForAddress[msg.sender][tokenNameIndex] -= amountNecessary;

                        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] >= amountNecessary);
                        require(balanceEthForAddress[msg.sender] + total_amount_ether_necessary >= balanceEthForAddress[msg.sender]);
                        require(tokenBalanceForAddress[tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].who][tokenNameIndex] + amountNecessary >= tokenBalanceForAddress[tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].who][tokenNameIndex]);

                        tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].amount -= amountNecessary;
                        balanceEthForAddress[msg.sender] += total_amount_ether_necessary;
                        tokenBalanceForAddress[tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].who][tokenNameIndex] += amountNecessary;

                        emit SellOrderFulfilled(tokenNameIndex, amountNecessary, whilePrice, offers_key);

                        amountNecessary = 0;
                    }
                    if (
                    offers_key == tokens[tokenNameIndex].buyBook[whilePrice].offers_length &&
                    tokens[tokenNameIndex].buyBook[whilePrice].offers[offers_key].amount == 0
                    ) {

                        tokens[tokenNameIndex].amountBuyPrices--;
                        if (whilePrice == tokens[tokenNameIndex].buyBook[whilePrice].lowerPrice || tokens[tokenNameIndex].buyBook[whilePrice].lowerPrice == 0) {
                            tokens[tokenNameIndex].curBuyPrice = 0;
                        }
                        else {
                            tokens[tokenNameIndex].curBuyPrice = tokens[tokenNameIndex].buyBook[whilePrice].lowerPrice;
                            tokens[tokenNameIndex].buyBook[tokens[tokenNameIndex].buyBook[whilePrice].lowerPrice].higherPrice = tokens[tokenNameIndex].curBuyPrice;
                        }
                    }
                    offers_key++;
                }

                whilePrice = tokens[tokenNameIndex].curBuyPrice;
            }

            if (amountNecessary > 0) {
                sellToken(symbolName, priceInWei, amountNecessary);
            }

        }
    }

    function addSellOffer(uint8 _tokenIndex, uint priceInWei, uint amount, address who) internal {
        tokens[_tokenIndex].sellBook[priceInWei].offers_length++;
        tokens[_tokenIndex].sellBook[priceInWei].offers[tokens[_tokenIndex].sellBook[priceInWei].offers_length] = Offer(amount, who);


        if (tokens[_tokenIndex].sellBook[priceInWei].offers_length == 1) {
            tokens[_tokenIndex].sellBook[priceInWei].offers_key = 1;
            tokens[_tokenIndex].amountSellPrices++;

            uint curSellPrice = tokens[_tokenIndex].curSellPrice;

            uint highestSellPrice = tokens[_tokenIndex].highestSellPrice;
            if (highestSellPrice == 0 || highestSellPrice < priceInWei) {
                if (curSellPrice == 0) {
                    tokens[_tokenIndex].curSellPrice = priceInWei;
                    tokens[_tokenIndex].sellBook[priceInWei].higherPrice = 0;
                    tokens[_tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                }
                else {
                    tokens[_tokenIndex].sellBook[highestSellPrice].higherPrice = priceInWei;
                    tokens[_tokenIndex].sellBook[priceInWei].lowerPrice = highestSellPrice;
                    tokens[_tokenIndex].sellBook[priceInWei].higherPrice = 0;
                }
                tokens[_tokenIndex].highestSellPrice = priceInWei;

            }
            else if (curSellPrice > priceInWei) {
                tokens[_tokenIndex].sellBook[curSellPrice].lowerPrice = priceInWei;
                tokens[_tokenIndex].sellBook[priceInWei].higherPrice = curSellPrice;
                tokens[_tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                tokens[_tokenIndex].curSellPrice = priceInWei;

            }
            else {

                uint sellPrice = tokens[_tokenIndex].curSellPrice;
                bool weFoundIt = false;
                while (sellPrice > 0 && !weFoundIt) {
                    if (
                    sellPrice < priceInWei &&
                    tokens[_tokenIndex].sellBook[sellPrice].higherPrice > priceInWei
                    ) {
                        tokens[_tokenIndex].sellBook[priceInWei].lowerPrice = sellPrice;
                        tokens[_tokenIndex].sellBook[priceInWei].higherPrice = tokens[_tokenIndex].sellBook[sellPrice].higherPrice;

                        tokens[_tokenIndex].sellBook[tokens[_tokenIndex].sellBook[sellPrice].higherPrice].lowerPrice = priceInWei;
                        tokens[_tokenIndex].sellBook[sellPrice].higherPrice = priceInWei;

                        weFoundIt = true;
                    }
                    sellPrice = tokens[_tokenIndex].sellBook[sellPrice].higherPrice;
                }
            }
        }
    }
    
    function cancelOrder(string symbolName, bool isSellOrder, uint priceInWei, uint offerKey) public {
        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        if (isSellOrder) {
            require(tokens[symbolNameIndex].sellBook[priceInWei].offers[offerKey].who == msg.sender);

            uint tokensAmount = tokens[symbolNameIndex].sellBook[priceInWei].offers[offerKey].amount;
            require(tokenBalanceForAddress[msg.sender][symbolNameIndex] + tokensAmount >= tokenBalanceForAddress[msg.sender][symbolNameIndex]);


            tokenBalanceForAddress[msg.sender][symbolNameIndex] += tokensAmount;
            tokens[symbolNameIndex].sellBook[priceInWei].offers[offerKey].amount = 0;
            emit SellOrderCanceled(symbolNameIndex, priceInWei, offerKey);

        }
        else {
            require(tokens[symbolNameIndex].buyBook[priceInWei].offers[offerKey].who == msg.sender);
            uint etherToRefund = tokens[symbolNameIndex].buyBook[priceInWei].offers[offerKey].amount * priceInWei;
            require(balanceEthForAddress[msg.sender] + etherToRefund >= balanceEthForAddress[msg.sender]);

            balanceEthForAddress[msg.sender] += etherToRefund;
            tokens[symbolNameIndex].buyBook[priceInWei].offers[offerKey].amount = 0;
            emit BuyOrderCanceled(symbolNameIndex, priceInWei, offerKey);
        }
    }
    
    function stringsEqual(string _a, string _b) internal pure returns (bool) {
        return keccak256(_a) == keccak256(_b);
    }
}
