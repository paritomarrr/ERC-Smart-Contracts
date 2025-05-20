const formatType = (schema) =>
  Object.entries(schema).map(([name, type]) => ({ name, type }));


  // Create a new object by mapping the values through a function, keeping the keys. Second function can be used to pre-filter entries
  // Example: mapValues({a:1,b:2,c:3}, x => x**2) -> {a:1,b:4,c:9}
 const  mapValues = (obj, fn, fn2 = () => true) =>
    Object.fromEntries(
      Object.entries(obj)
        .filter(fn2)
        .map(([k, v]) => [k, fn(v)])
    );


const types = mapValues(
  {
    EIP712Domain: {
      name: "string",
      version: "string",
      chainId: "uint256",
      verifyingContract: "address",
      salt: "bytes32",
    },
    Permit: {
      owner: "address",
      spender: "address",
      value: "uint256",
      nonce: "uint256",
      deadline: "uint256",
    },
    Ballot: {
      proposalId: "uint256",
      support: "uint8",
      voter: "address",
      nonce: "uint256",
    },
    ExtendedBallot: {
      proposalId: "uint256",
      support: "uint8",
      voter: "address",
      nonce: "uint256",
      reason: "string",
      params: "bytes",
    },
    OverrideBallot: {
      proposalId: "uint256",
      support: "uint8",
      voter: "address",
      nonce: "uint256",
      reason: "string",
    },
    Delegation: {
      delegatee: "address",
      nonce: "uint256",
      expiry: "uint256",
    },
    ForwardRequest: {
      from: "address",
      to: "address",
      value: "uint256",
      gas: "uint256",
      nonce: "uint256",
      deadline: "uint48",
      data: "bytes",
    },
  },
  formatType
);

module.exports = {
    mapValues,
    formatType,
    types,
};
