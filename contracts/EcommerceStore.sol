pragma solidity >=0.5.16;

contract EcommerceStore {
    enum ProductStatus { Open, Sold, Unsold }
    enum ProductCondition { New, Used }

    uint public productIndex;
    mapping (address => mapping(uint => Product)) stores;
    mapping (uint => address) productIdInStore;

    struct Product {
        uint id;
        string name;
        string category;
        string imageLink;
        string descLink;
        uint auctionStartTime;
        uint auctionEndTime;
        uint startPrice;
        address payable highestBidder;
        uint highestBid;
        uint secondHighestBid;
        uint totalBids;
        ProductStatus status;
        ProductCondition condition;
        mapping (address => mapping (bytes32 => Bid)) bids;
    }

    struct Bid {
        address bidder;
        uint productId;
        uint value;
        bool revealed;
    }

    constructor() public {
       productIndex = 0;
    }

    function addProductToStore(string memory _name, string memory _category, string memory _imageLink,
     string memory _descLink, uint _auctionStartTime,
     uint _auctionEndTime, uint _startPrice, uint _productCondition) public {
        require (_auctionStartTime < _auctionEndTime,"error1");
        productIndex += 1;
        Product memory product = Product(productIndex, _name, _category, _imageLink, _descLink, _auctionStartTime, _auctionEndTime,
        _startPrice, address(0), 0, 0, 0, ProductStatus.Open, ProductCondition(_productCondition));
        stores[msg.sender][productIndex] = product;
        productIdInStore[productIndex] = msg.sender;
    }

    function getProduct(uint _productId)public view
     returns (uint, string memory, string memory, string memory, string memory, uint, uint, uint, ProductStatus, ProductCondition) {
        Product memory product = stores[productIdInStore[_productId]][_productId];
        return (product.id, product.name, product.category, product.imageLink, product.descLink, product.auctionStartTime,
            product.auctionEndTime, product.startPrice, product.status, product.condition);
    }

    function  bid (uint _productId,bytes32 _bid) public payable returns (bool) {
        Product storage product = stores [productIdInStore [_productId]] [_productId];
        require (now>=product.auctionStartTime,"error 2");
        require (now <= product.auctionEndTime,"error 3");
        require (msg.value > product.startPrice,"error 4");
        require (product.bids[msg.sender][_bid].bidder == address(0),"error 5");
        product.bids[msg.sender][_bid] = Bid(msg.sender,_productId,msg.value,false);
        product.totalBids += 1;
        return  true ;
        }

    function  revealBid (uint _productId,string memory _amount,string memory _secret) public {
        Product storage product = stores [productIdInStore[_productId]][_productId];
        require(now > product.auctionEndTime,"error6");
        bytes32 sealedBid = keccak256(abi.encodePacked(_amount, _secret));

        // Memory bidInfo Bid = Product.Bids[msg.sender][sealedBid];
        // the require(bidInfo.Bidder > 0);
        // the require(bidInfo.Revealed == to false);
        Bid memory bidInfo = product.bids[msg.sender][sealedBid];
        require(bidInfo.bidder > address(0),"error7");
        require (bidInfo.revealed == false,"error8");

        uint refund;

        uint amount = stringToUint(_amount);

        if(bidInfo.value < amount){
            // They didn't send enough amount, they lost
        refund = bidInfo.value;
        }
        else{
            // If first to reveal set as highest bidder
            if(address(product.highestBidder) == address(0)){
                product.highestBidder = msg.sender;
                product.highestBid = amount;
                product.secondHighestBid = product.startPrice;
                refund = bidInfo.value - amount;
            }
            else{
                if(amount > product.highestBid){
                    product.secondHighestBid = product.highestBid;
                    product.highestBidder.transfer(product.highestBid);
                    product.highestBidder = msg.sender;
                    product.highestBid = amount;
                    refund = bidInfo.value - amount;
                }
                else if(amount > product.secondHighestBid){
                    product.secondHighestBid = amount;
                    refund = bidInfo.value;
                }
                else{
                    refund = bidInfo.value;
                }
            }
        }
        product.bids[msg.sender][sealedBid].revealed = true;
        if(refund > 0){
        msg.sender.transfer(refund);
        }
    }

    function highestBidderInfo(uint _productId) public view returns (address,uint,uint){
        Product memory product = stores[productIdInStore[_productId]][_productId];
        return(product.highestBidder,product.highestBid,product.secondHighestBid);
    }

    function totalBids(uint _productId) public view returns (uint){
        Product memory product = stores[productIdInStore[_productId]][_productId];
        return product.totalBids;
    }

    function stringToUint(string memory s) private pure returns(uint){
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0;i < b.length;i++){
            if (b[i] >= 0x30 && b[i] <= 0x39){
                result = result * 10+(uint(uint8(b[i]))-48);
            }
        }
        return result;
    }


}