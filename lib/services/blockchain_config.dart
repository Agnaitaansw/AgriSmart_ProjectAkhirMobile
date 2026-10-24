class BlockchainConfig {
  BlockchainConfig._();

  static const String rpcUrl = 'https://ethereum-sepolia-rpc.publicnode.com';
  static const int chainId = 11155111; // Sepolia

  /// Alamat kontrak dari Etherscan/Remix (diawali 0x)
  static const String contractAddress = '0xEB7f9637171d12a551d919A8DAdf4103bbEBC5A7';

  /// Private key MetaMask akun yang sama dengan yang deploy kontrak
  static const String privateKey = '744012d476eab6387b734c155d67b6e98930459f208f674079839d55bac2ee76';

  static const String explorerTx = 'https://sepolia.etherscan.io/tx/';

  static bool get siap =>
      contractAddress.startsWith('0x') && !privateKey.startsWith('ISI_');

  static const String abi = '''
[
  {"type":"function","name":"catat","stateMutability":"nonpayable",
   "inputs":[{"name":"userId","type":"uint256"},{"name":"poin","type":"int256"},{"name":"aksi","type":"string"}],
   "outputs":[]},
  {"type":"function","name":"saldo","stateMutability":"view",
   "inputs":[{"name":"","type":"uint256"}],
   "outputs":[{"name":"","type":"int256"}]},
  {"type":"function","name":"jumlahCatatan","stateMutability":"view",
   "inputs":[{"name":"userId","type":"uint256"}],
   "outputs":[{"name":"","type":"uint256"}]},
  {"type":"function","name":"verifikasi","stateMutability":"view",
   "inputs":[{"name":"userId","type":"uint256"}],
   "outputs":[{"name":"","type":"bool"}]}
]
''';
}