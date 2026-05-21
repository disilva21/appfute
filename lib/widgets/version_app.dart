import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersaoDoAppWidget extends StatelessWidget {
  const VersaoDoAppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey));
        }

        if (snapshot.hasData) {
          final info = snapshot.data!;
          // info.version = '1.0.0'
          // info.buildNumber = '1'
          return Text(
            "Versão ${info.version} (${info.buildNumber})",
            style: TextStyle(fontSize: 12, color: Colors.white, fontStyle: FontStyle.italic),
          );
        }

        return const Text("");
      },
    );
  }
}
