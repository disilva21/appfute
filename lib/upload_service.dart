import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class UploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<String?> selecionarEUpload({required String pasta, required String idDocumento}) async {
    try {
      // 1. Selecionar imagem da galeria
      final XFile? imagemSelecionada = await _picker.pickImage(source: ImageSource.gallery);

      if (imagemSelecionada == null) return null;

      // 2. Aplicar o Crop (Recorte)
      final CroppedFile? imagemCortada = await ImageCropper().cropImage(
        sourcePath: imagemSelecionada.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Força proporção 1:1 (Quadrado)
        compressQuality: 70, // Já comprime no momento do crop
        maxWidth: 500, // Limita a largura máxima
        maxHeight: 500, // Limita a altura máxima
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Imagem',
            toolbarColor: const Color(0xFF00A335), // Verde do seu tema
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true, // Impede o usuário de fazer cortes retangulares
          ),
          IOSUiSettings(title: 'Ajustar Imagem', aspectRatioLockEnabled: true, resetButtonHidden: false),
        ],
      );

      if (imagemCortada == null) return null; // Usuário cancelou no momento do corte

      File arquivoFinal = File(imagemCortada.path);

      // 3. Referência e Upload para o Storage (Igual ao anterior)
      Reference ref = _storage.ref().child(pasta).child('$idDocumento.jpg');
      UploadTask uploadTask = ref.putFile(arquivoFinal);
      TaskSnapshot snapshot = await uploadTask;

      String? urlDaFoto = await snapshot.ref.getDownloadURL();

      if (pasta == 'perfil') {
        await FirebaseFirestore.instance.collection('jogadores').doc(FirebaseAuth.instance.currentUser?.uid).update({
          'urlFotoPerfil': urlDaFoto,
          'atualizadoEm': FieldValue.serverTimestamp(), // Boa prática para controle interno
        });
      }

      // 4. Retorna a URL pública
      return urlDaFoto;
    } catch (e) {
      print("Erro no upload com crop: $e");
      return null;
    }
  }
}
