import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../core/crypto/key_manager.dart';
import '../core/storage/file_storage.dart';
import '../core/utils/path_utils.dart';

class ContactProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final KeyManager _keyManager = KeyManager();
  final Map<String, Contact> _contacts = {};

  List<Contact> get contacts => _contacts.values.toList();

  Future<void> loadContacts() async {
    final basePath = await PathUtils.getAppBasePath();
    final contactsFile = File('$basePath/contacts.json');

    Map<String, dynamic> contactsData = {};
    if (await contactsFile.exists()) {
      try {
        final content = await contactsFile.readAsString();
        contactsData = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        // Ignore parse errors
      }
    }

    final contactIds = await _storageService.listContactPublicKeys();
    _contacts.clear();

    for (final id in contactIds) {
      final publicKeyPem = await _storageService.loadContactPublicKey(id);
      if (publicKeyPem != null) {
        final contactData = contactsData[id] as Map<String, dynamic>?;
        _contacts[id] = Contact(
          id: id,
          name: contactData?['name'] ?? id,
          publicKeyPem: publicKeyPem,
          privateKeyId: contactData?['privateKeyId'],
          createdAt: contactData != null
              ? DateTime.parse(
                  contactData['createdAt'] ?? DateTime.now().toIso8601String(),
                )
              : DateTime.now(),
        );
      }
    }
    notifyListeners();
  }

  Future<void> addContact(
    String name,
    String publicKeyPem, {
    String? privateKeyId,
  }) async {
    final id = name;
    final contact = Contact(
      id: id,
      name: name,
      publicKeyPem: _keyManager.extractPublicKeyPem(publicKeyPem),
      privateKeyId: privateKeyId,
      createdAt: DateTime.now(),
    );

    _contacts[id] = contact;
    await _storageService.saveContactPublicKey(id, contact.publicKeyPem!);
    await _saveContactsMetadata();
    notifyListeners();
  }

  Future<void> updateContact(Contact contact) async {
    _contacts[contact.id] = contact;
    if (contact.publicKeyPem != null) {
      await _storageService.saveContactPublicKey(
        contact.id,
        contact.publicKeyPem!,
      );
    }
    await _saveContactsMetadata();
    notifyListeners();
  }

  Future<void> deleteContact(String contactId) async {
    _contacts.remove(contactId);
    await _storageService.deleteContactPublicKey(contactId);
    await _saveContactsMetadata();
    notifyListeners();
  }

  Contact? getContact(String contactId) {
    return _contacts[contactId];
  }

  bool hasPublicKey(String contactId) {
    return _contacts[contactId]?.publicKeyPem != null;
  }

  void clearState() {
    _contacts.clear();
    notifyListeners();
  }

  Future<void> _saveContactsMetadata() async {
    final basePath = await PathUtils.getAppBasePath();
    final contactsFile = File('$basePath/contacts.json');

    final data = <String, dynamic>{};
    for (final contact in _contacts.values) {
      data[contact.id] = {
        'name': contact.name,
        'privateKeyId': contact.privateKeyId,
        'createdAt': contact.createdAt.toIso8601String(),
      };
    }

    await contactsFile.writeAsString(jsonEncode(data));
  }
}
