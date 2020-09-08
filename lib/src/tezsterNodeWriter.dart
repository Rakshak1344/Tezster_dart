import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:core';

import 'package:blake2b/blake2b_hash.dart';
import 'package:flutter/material.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:flutter_sodium/flutter_sodium.dart';
import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;
import 'package:tezster_dart/tezster_dart.dart';

class TezsterNodeWriter {
  static performPostRequest({
    String server,
    String command,
    Object payload,
  }) async {
    assert(server != null);
    assert(command != null);
    String url = '$server/$command';
    try {
      String payloadString = jsonEncode(payload);
      http.Response data = await http.post(
        url,
        body: payloadString,
        headers: {
          'content-type': 'application/json',
        },
      );
      return data;
    } catch (e) {
      return {"message": "Something went wrong"};
    }
  }

  static Uint8List _simpleHash(Uint8List payload, int digestSize) {
    return Blake2bHash.hashWithDigestSize(digestSize, payload);
  }

  static Uint8List _writeKeyWithHint(String key, String hint) {
    if (hint == "edsk" || hint == "edpk") {
      return bs58check.decode(key).sublist(0, 64);
    } else {
      throw {"message": "Unrecognized key hint, '$hint'"};
    }
  }

  static String _readSignatureWithHint(Uint8List payload, String hint) {
    List<int> intConversionPayload = List.from(payload);
    String encodedPayoad = hex.encode(intConversionPayload);
    String concatEncodedPayload = '09f5cd8612' + encodedPayoad;
    String encodedPayoadToHexString =
        hex.encode(concatEncodedPayload.codeUnits);
    Uint8List finlaListForBS58CHECK = hex.decode(encodedPayoadToHexString);
    print(finlaListForBS58CHECK);
    if (hint == 'edsig') {
      String bs58checkVal = bs58check.encode(finlaListForBS58CHECK);
      var encodedHex = hex.encode(bs58checkVal.codeUnits);
      print(encodedHex);
      return bs58checkVal;
    } else {
      throw {"message": "Unrecognized key hint, '$hint'"};
    }
  }

  static Future<Uint8List> _signDetach(Uint8List message, Uint8List sk) async {
    print("message ===> $message");
    print("sk ===> $sk");
    return Sodium.cryptoSignDetached(message, sk);
  }

  static Future<SignedOperationGroup> signOperationGroup({
    String forgedOperation,
    String derivationPath,
    String privateKey,
  }) async {
    assert(forgedOperation != null);
    assert(privateKey != null);
    String watermarkedForgedOperationBytesHex = "03" + forgedOperation;
    String stringToHexString =
        hex.encode(watermarkedForgedOperationBytesHex.codeUnits);
    // print(stringToHexString);
    List<int> hexStringToListOfInt = hex.decode(stringToHexString);
    // print(hexStringToListOfInt);
    Uint8List hashedWatermarkedOpBytes = _simpleHash(hexStringToListOfInt, 256);
    // print("hashedWatermarkedOpBytes ===> $hashedWatermarkedOpBytes");
    // print("hashedWatermarkedOpBytes ===> ${hashedWatermarkedOpBytes.length}");
    Uint8List privateKeyBytes = _writeKeyWithHint(privateKey, "edsk");
    // print("bs58List ===> $privateKeyBytes");

    Uint8List opSignature =
        await _signDetach(hashedWatermarkedOpBytes, privateKeyBytes);
    print("opSignature ===> $opSignature");

    String hexString = _readSignatureWithHint(opSignature, 'edsig');
    // var data = hex.decode(hexString);
    // print(data);
    // print("hexString ===> $hexString");

    List listforgedOperation = hex.decode(forgedOperation);
    Uint8List uint8ListforgedOperation =
        Uint8List.fromList(listforgedOperation);
    List signedOpBytes = uint8ListforgedOperation + opSignature;
    // print("signedOpBytes ===> $signedOpBytes");

    return SignedOperationGroup(bytes: signedOpBytes, signature: hexString);
  }

  // FORGED OPERATION GROUP

  static String twoByteHex(int n) {
    if (n < 128) {
      String hexString = "0" + n.toRadixString(16);
      return hexString.substring(hexString.length - 2);
    }

    String h = '';

    if (n > 2147483648) {
      BigInt r = BigInt.from(n);
      while (r > BigInt.zero) {
        //Review
        String data = ('0' + r.toRadixString(16) + 127.toRadixString(16));
        h = data.substring(data.length - 2) + h;
        r = r >> 7;
      }
    } else {
      int r = n;
      while (r > 0) {
        // Review
        String data = ('0' + (r & 127).toRadixString(16));
        h = data.substring(data.length - 2) + h;
        r = r >> 7;
      }
    }
    return h;
  }

  static String writeInt(int value) {
    if (value < 0) {
      return "Use writeSignedInt to encode negative numbers";
    }

    String twoByteHexString = twoByteHex(value);
    print("twoByteHexString ==> $twoByteHexString");

    List<int> hexStringToList = hex.decode(twoByteHexString);
    print("hexStringToList ===> $hexStringToList");

    Uint8List twoByteUint8List = Uint8List.fromList(hexStringToList);
    print("twoByteUint8List ===> $twoByteUint8List");

    Map mapData = twoByteUint8List.asMap();
    print("mapData ===> $mapData");

    List<int> hexList = [];

    mapData.forEach((key, value) {
      var hexValue = key == 0 ? value : value ^ 0x80;
      print(key.toString() + " " + value.toString());
      print(hexValue);
      hexList.add(hexValue);
    });
    print("hexList ===> $hexList");

    List reversedList = (hexList.reversed).toList();

    Uint8List conversion = Uint8List.fromList((hexList.reversed).toList());
    print("conversion $conversion");

    String reversedIntListDataToHex = hex.encode(reversedList);
    print("reversedIntListDataToHex ===> $reversedIntListDataToHex");

    return reversedIntListDataToHex;
  }

  static Map<String, int> sepyTnoitarepo = {
    'endorsement': 0,
    'seedNonceRevelation': 1,
    'doubleEndorsementEvidence': 2,
    'doubleBakingEvidence': 3,
    'accountActivation': 4,
    'proposal': 5,
    'ballot': 6,
    'reveal': 7,
    'transaction': 8,
    'origination': 9,
    'delegation': 10,
    'Newreveal': 107,
    'Newtransaction': 108,
    'Neworigination': 109,
    'Newdelegation': 110
  };

  static String encodeActivation(Activation operation) {
    String hexString = writeInt(sepyTnoitarepo['accountActivation']);
    // print("writeIntHex ===> $writeIntHex");
    String hexCode = writeAddress(operation.pkh);
    // print("hexCode ===> $hexCode");
    hexString += hexCode.substring(4);
    hexString += operation.secret;
    return hexString;
  }

  static String encodeReveal(Reveal reveal) {
    String hexString = writeInt(sepyTnoitarepo['reveal']);
    hexString += writeAddress(reveal.source).substring(2);
    hexString += writeInt(int.parse(reveal.fee));
    hexString += writeInt(int.parse(reveal.counter));
    hexString += writeInt(int.parse(reveal.gasLimit));
    hexString += writeInt(int.parse(reveal.storageLimit));
    hexString += writePublicKey(reveal.publicKey);
    return hexString;
  }

  /// TODO : This is pending [normalizeMichelineWhiteSpace] function
  static String normalizeMichelineWhiteSpace(String compositevalue) {
    return compositevalue
        .replaceAll(RegExp('/ +/g'), ' ')
        .replaceAll(RegExp(r'/\[{/g'), '[ {')
        .replaceAll(RegExp('/}\]/g'), '} ]')
        .replaceAll(RegExp('/},{/g'), '}, {')
        .replaceAll(RegExp('/\]}/g'), '] }')
        .replaceAll(RegExp('/":"/g'), '": "')
        .replaceAll(RegExp(r'/":\[/g'), '": [')
        .replaceAll(RegExp('/{"/g'), '{ "')
        .replaceAll(RegExp('/"}/g'), '" }')
        .replaceAll(RegExp('/,"/g'), ', "')
        .replaceAll(RegExp('/","/g'), '", "')
        .replaceAll(RegExp(r'/\[\[/g'), '[ [')
        .replaceAll(RegExp('/\]\]/g'), '] ]')
        .replaceAll(RegExp(r'/\["/g'), '\[ "')
        .replaceAll(RegExp('/"\]/g'), '" \]')
        .replaceAll(RegExp('/\[ +\]/g'), '\[\]')
        .trim();
    // return compositevalue.replace(RegExp(/ +/g), ' ');
  }

  static String prettyJson(Map<String, dynamic> json, {int indent = 4}) {
    var spaces = ' ' * indent;
    var encoder = JsonEncoder.withIndent(spaces);
    return encoder.convert(json);
  }

  static String translateMichelineToHex(String code) {
    return "";
  }

  static String encodeTransaction(Transaction transaction) {
    String hexString = writeInt(sepyTnoitarepo['transaction']);
    hexString += writeAddress(transaction.source).substring(2);
    hexString += writeInt(int.parse(transaction.fee));
    hexString += writeInt(int.parse(transaction.counter));
    hexString += writeInt(int.parse(transaction.gasLimit));
    hexString += writeInt(int.parse(transaction.storageLimit));
    hexString += writeInt(int.parse(transaction.amount));
    // hexString += writeInt(int.parse(transaction.destination));

    if (transaction.contractParameters != null) {
      ContractParameters composite = transaction.contractParameters;

      // TODO : TranslateMichelineToHex to be done
      String code = normalizeMichelineWhiteSpace(jsonEncode(composite.value));
      String result = translateMichelineToHex(code);

      if ((composite.entrypoint == 'default' || composite.entrypoint == '') &&
          result == '030b') {
        hexString += '00';
      } else {
        hexString += 'ff';

        if (composite.entrypoint == 'default' || composite.entrypoint == '') {
          hexString += '00';
        } else if (composite.entrypoint == 'root') {
          hexString += '01';
        } else if (composite.entrypoint == 'do') {
          hexString += '02';
        } else if (composite.entrypoint == 'set_delegate') {
          hexString += '03';
        } else if (composite.entrypoint == 'remove_delegate') {
          hexString += '04';
        } else {
          hexString += 'ff' +
              ('0' + composite.entrypoint.length.toRadixString(16))
                  .substring(2) +
              composite.entrypoint
                  .split('')
                  .map((c) => c.codeUnitAt(0).toRadixString(16))
                  .join();
        }

        if (result == '030b') {
          hexString += '00';
        } else {
          int resultLengthDiv2 = int.parse((result.length / 2).toString());
          String data = ('0000000' + resultLengthDiv2.toRadixString(16));
          hexString += data.substring(data.length - 8) + result;
        }
      }
    } else {
      hexString += '00';
    }

    return hexString;
  }

  static String encodeOrigination(Origination origination) {
    String hexString = writeInt(sepyTnoitarepo['origination']);
    hexString = writeAddress(origination.source).substring(2);
    hexString = writeInt(int.parse(origination.fee));
    hexString = writeInt(int.parse(origination.counter));
    hexString = writeInt(int.parse(origination.gasLimit));
    hexString = writeInt(int.parse(origination.storageLimit));
    hexString = writeInt(int.parse(origination.balance));

    writeBoolean(bool value) => value ? "ff" : "00";

    if (origination.delegate != null) {
      hexString += writeBoolean(true);
      hexString += writeAddress(origination.delegate).substring(2);
    } else {
      hexString += writeBoolean(false);
    }

    if (origination.script) {
      List<String> parts = [];
      parts.add(origination.script['code']);
      parts.add(origination.script['storage']);

      /// TODO : Pending to review [normalizeMichelineWhiteSpace] and [translateMichelineToHex].
      // hexString +=
      //     parts.
    }
    return hexString;
  }

  static String encodeDelegation(Delegation delegation) {
    String hexString = writeInt(sepyTnoitarepo['delegation']);

    /// Review [hexCode]
    String hexCode = writeAddress(delegation.source);
    hexString += hexCode.substring(2);
    hexString += writeInt(int.parse(delegation.fee));
    hexString += writeInt(int.parse(delegation.counter));
    hexString += writeInt(int.parse(delegation.gasLimit));
    hexString += writeInt(int.parse(delegation.storageLimit));

    //tobe moved to seperate file
    writeBoolean(bool value) => value ? "ff" : "00";

    if (delegation.delegate != null && delegation.delegate != "") {
      hexString += writeBoolean(true);
      // String writeAddressForDelegation = ;
      hexString += writeAddress(delegation.delegate).substring(2);
    } else {
      hexString += writeBoolean(false);
    }

    return hexString;
  }

  static String encodeBallot(Ballot ballot) {
    Uint8List writeBufferWithInt(String value) => bs58check.decode(value);

    String hexString = writeInt(sepyTnoitarepo['ballot']);
    hexString += writeAddress(ballot.source).substring(2);
    String ballotPeriodHexString = '00000000' + ballot.period.toRadixString(16);
    hexString +=
        ballotPeriodHexString.substring(ballotPeriodHexString.length - 8);

    Uint8List ballotProposalList = writeBufferWithInt(ballot.proposal);
    String ballotProposalHexString = hex.encode(ballotProposalList);

    hexString += ballotProposalHexString.substring(4);
    String ballotVote = '00' + ballot.vote.toRadixString(16);
    hexString += ballotVote.substring(ballotVote.length - 2);
    return hexString;
  }

  static writePublicKey(String publicKey) {
    String _decodeAndAdd(String number) {
      Uint8List publicKeyList = bs58check.decode(publicKey).sublist(4);
      return number + hex.encode(publicKeyList);
    }

    if (publicKey.startsWith("edpk")) {
      return _decodeAndAdd("00");
    } else if (publicKey.startsWith("sppk")) {
      return _decodeAndAdd("01");
    } else if (publicKey.startsWith("p2pk")) {
      return _decodeAndAdd("02");
    }
  }

  static String writeAddress(String address) {
    Uint8List uintBsList = bs58check.decode(address).sublist(3);
    // List<int> bsList = List.from(uintBsList);
    String hexString = hex.encode(uintBsList);
    // print("hexString ===> $hexString");

    if (address.startsWith("tz1")) {
      return "0000" + hexString;
    } else if (address.startsWith("tz2")) {
      return "0001" + hexString;
    } else if (address.startsWith("tz3")) {
      return "0002" + hexString;
    } else if (address.startsWith("KT1")) {
      return "01" + hexString + "00";
    } else {
      throw new ErrorDescription("Unrecognized address prefix: ");
    }
  }

  static forgeOperations({
    String branch,
    dynamic operation,
  }) {
    String encoded = _writeBranch(branch);
    print("encoded ===> $encoded");
    encoded += encodeOperationValue(operation);
    // print("encoded ===> $newEncode");
    return encoded;
  }

  static encodeOperationValue(operation) {
    if (operation is Activation) {
      return encodeActivation(Activation(
        pkh: operation.pkh,
        secret: operation.secret,
      ));
    } else if (operation is Reveal) {
      return encodeReveal(Reveal(
        source: operation.source,
        fee: operation.fee,
        counter: operation.counter,
        gasLimit: operation.gasLimit,
        publicKey: operation.publicKey,
        storageLimit: operation.storageLimit,
      ));
    } else if (operation is Transaction) {
      return encodeTransaction(Transaction(
        amount: operation.amount,
        counter: operation.counter,
        destination: operation.destination,
        contractParameters: operation.contractParameters,
        fee: operation.fee,
        gasLimit: operation.gasLimit,
        source: operation.source,
        storageLimit: operation.storageLimit,
      ));
    } else if (operation is Origination) {
      return encodeOrigination(Origination(
        source: operation.source,
        balance: operation.balance,
        counter: operation.counter,
        fee: operation.fee,
        gasLimit: operation.gasLimit,
        storageLimit: operation.storageLimit,
        delegate: operation.delegate,
        delegatable: operation.delegatable,
        managerPubkey: operation.managerPubkey,
        script: operation.script,
        spendable: operation.spendable,
      ));
    } else if (operation is Delegation) {
      return encodeDelegation(Delegation(
        source: operation.source,
        fee: operation.fee,
        counter: operation.counter,
        gasLimit: operation.gasLimit,
        storageLimit: operation.storageLimit,
        delegate: operation.delegate,
      ));
    } else if (operation is Ballot) {
      return encodeBallot(Ballot(
        source: operation.source,
        period: operation.period,
        proposal: operation.proposal,
        vote: operation.vote,
      ));
    }
  }

  static String _writeBranch(String branch) {
    Uint8List branchUint8List = bs58check.decode(branch).sublist(2);
    String branchHexString = hex.encode(branchUint8List);
    return branchHexString;
  }

  /// TODO :  Send Transaction Operation
  static sendTransactionOperation({
    String server,
    KeyStore keyStore,
    String to,
    int amount,
    int fee,
    String derivationPath = '',
  }) async {
    dynamic counter = await TezsterNodeReader.getCounterForAccount(
            server: server, accountHash: keyStore.publicKeyHash) +
        1;
    Transaction transaction = Transaction(
      destination: to,
      amount: amount.toString(),
      storageLimit: 496.toString(),
      gasLimit: 10600.toString(),
      counter: counter.toString(),
      fee: fee.toString(),
      source: keyStore.publicKeyHash,
    );

    /// [appendRevealOperation]
    dynamic transactionOperation = await appendRevealOperation(
      server: server,
      keyStore: keyStore,
      accountHash: keyStore.publicKeyHash,
      accountOperationIndex: counter - 1,
      transactions: transaction,
    );
    print("transactionOperation ===> ${transactionOperation.source}");

    return sendOperation(
        server, transactionOperation, keyStore, derivationPath);
  }

  static sendOperation(String server, dynamic operations, KeyStore keyStore,
      String derivationPath) async {
    var blockHead = await TezsterNodeReader.getBlockHead(server: server);
    print("blockHead ===> ${blockHead['hash']}");
    var forgedOperationGroup =
        forgeOperations(branch: blockHead['hash'], operation: operations);
    SignedOperationGroup signedOpGroup = await signOperationGroup(
      forgedOperation: forgedOperationGroup,
      privateKey: keyStore.privateKey,
      derivationPath: derivationPath,
    );
    print("signedOpGroup ===> ${signedOpGroup.signature}");

    var injectedOperation =
        await injectOperation(server: server, signedOpGroup: signedOpGroup);

    var appliedOp = await preapplyOperation(
      server: server,
      branch: blockHead['hash'],
      protocol: blockHead['protocol'],
      keyStore: keyStore,
      signedOpGroup: signedOpGroup,
    );
    print("appliedOp ===> $appliedOp");
    // server, blockHead.hash, blockHead.protocol, operations, signedOpGroup);

    /// TODO : Pending Task
    return {"results": appliedOp[0], "operationGroupID": injectedOperation};
  }

  static Future<dynamic> injectOperation({
    String server,
    SignedOperationGroup signedOpGroup,
    String chainid = 'main',
  }) {
    var signedOpByteHex = hex.encode(signedOpGroup.bytes);
    print("signedOpByteHex ===> $signedOpByteHex");
    var response = performPostRequest(
      server: server,
      command: "injection/operation?chain=$chainid",
      payload: signedOpByteHex,
    );
    print("response ===> $response");
    return response;
  }

  static preapplyOperation({
    String server,
    String branch,
    String protocol,
    KeyStore keyStore,
    SignedOperationGroup signedOpGroup,
    String chainid = 'main',
  }) async {
    List payload = [
      {
        "protocol": protocol,
        "branch": branch,
        "contents": keyStore,
        "signature": signedOpGroup.signature
      }
    ];
    var response = await performPostRequest(
      server: server,
      command: "chains/$chainid/blocks/head/helpers/preapply/operations",
      payload: json.encode(payload),
    );

    return response;
  }

  static appendRevealOperation({
    @required String server,
    @required dynamic keyStore,
    @required String accountHash,
    @required int accountOperationIndex,
    @required dynamic transactions,
  }) async {
    bool isKeyRevealed = await TezsterNodeReader.isManagerKeyRevealedForAccount(
        server: server, accountHash: accountHash);
    int counter = accountOperationIndex + 1;

    if (!isKeyRevealed) {
      Reveal revealOp = Reveal(
        source: accountHash,
        fee: '0',
        counter: counter.toString(),
        gasLimit: '10600',
        storageLimit: '0',
        publicKey: keyStore.publicKey,
      );

      transactions.forEach((transaction, i) {
        var c = accountOperationIndex + 2 + i;
        transaction.counter = c.toString();
      });

      return [revealOp, ...transactions];
    }
    return transactions;
  }
}

enum StoreType { mnemonic, fundraiser, hardware }

class KeyStore {
  String publicKey;
  String privateKey;
  String publicKeyHash;
  String seed;
  String derivationPath;
  StoreType storeType = StoreType.mnemonic;
  KeyStore({
    this.publicKey,
    this.privateKey,
    this.publicKeyHash,
    this.seed,
    this.derivationPath,
    this.storeType,
  });

  KeyStore.fromJson(Map<String, dynamic> json) {
    publicKey = json['publicKey'];
    privateKey = json['privateKey'];
    publicKeyHash = json['publicKeyHash'];
    seed = json['seed'];
    derivationPath = json['derivationPath'];
    storeType = json['storeType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['publicKey'] = this.publicKey;
    data['privateKey'] = this.privateKey;
    data['publicKeyHash'] = this.publicKeyHash;
    data['seed'] = this.seed;
    data['derivationPath'] = this.derivationPath;
    data['storeType'] = this.storeType;
    return data;
  }
}

class SignedOperationGroup {
  List<int> bytes;
  String signature;
  SignedOperationGroup({this.bytes, this.signature});
}

class Activation {
  String pkh;
  String secret;
  Activation({this.pkh, this.secret});
}

class Ballot {
  String source;
  int period;
  String proposal;
  //Review
  int vote;
  Ballot({this.source, this.period, this.proposal, this.vote});
}

// class BallotVote {
//     int yay = 0;
//     int nay = 1;
//     int pass = 2;
//     BallotVote({this.nay,this.pass,this.yay});
// }

class Transaction {
  String source;
  String fee;
  String counter;
  String gasLimit;
  String storageLimit;
  String amount;
  String destination;
  ContractParameters contractParameters;
  Transaction({
    this.source,
    this.fee,
    this.counter,
    this.gasLimit,
    this.storageLimit,
    this.amount,
    this.destination,
    this.contractParameters,
  });
}

class ContractParameters {
  String entrypoint;
  dynamic value;
  ContractParameters({
    this.entrypoint,
    this.value,
  });
}

class Delegation {
  String source;
  String fee;
  String counter;
  String gasLimit;
  String storageLimit;
  String delegate;
  Delegation({
    this.source,
    this.fee,
    this.counter,
    this.gasLimit,
    this.storageLimit,
    this.delegate,
  });
}

class Reveal {
  String source;
  String fee;
  String counter;
  String gasLimit;
  String storageLimit;
  String publicKey;
  Reveal({
    this.source,
    this.fee,
    this.counter,
    this.gasLimit,
    this.storageLimit,
    this.publicKey,
  });
}

class Origination {
  String source;
  String fee;
  String counter;
  String gasLimit;
  String storageLimit;
  String managerPubkey; // deprecated in P005
  String balance;
  bool spendable; // deprecated in P005
  bool delegatable; // deprecated in P005
  String delegate;
  dynamic script;
  Origination({
    this.source,
    this.fee,
    this.counter,
    this.gasLimit,
    this.storageLimit,
    this.managerPubkey,
    this.balance,
    this.spendable,
    this.delegatable,
    this.delegate,
    this.script,
  });
}
