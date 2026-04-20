class Constants {
  static const String appName = 'SecretChat';
  static const String appDataDir = 'secretchat';
  static const String keysDir = 'keys';
  static const String contactsDir = 'contacts';

  static const int maxFileSize = 50 * 1024 * 1024;
  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 16;
  static const int ivLength = 12;

  static const String defaultKeyType = 'RSA';
  static const int defaultKeySize = 2048;

  static const String pemHeaderRsaPublicKey = '-----BEGIN PUBLIC KEY-----';
  static const String pemFooterRsaPublicKey = '-----END PUBLIC KEY-----';
  static const String pemHeaderRsaPrivateKey =
      '-----BEGIN RSA PRIVATE KEY-----';
  static const String pemFooterRsaPrivateKey = '-----END RSA PRIVATE KEY-----';
  static const String pemHeaderEcPublicKey = '-----BEGIN PUBLIC KEY-----';
  static const String pemFooterEcPublicKey = '-----END PUBLIC KEY-----';
  static const String pemHeaderEcPrivateKey = '-----BEGIN EC PRIVATE KEY-----';
  static const String pemFooterEcPrivateKey = '-----END EC PRIVATE KEY-----';

  static const String qrKeyPrefix = 'SECRETPCHAT:PUBKEY:';
}
