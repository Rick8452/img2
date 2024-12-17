import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const ImageRecognition(),
    );
  }
}

class ImageRecognition extends StatefulWidget {
  const ImageRecognition({Key? key}) : super(key: key);

  @override
  State<ImageRecognition> createState() => _ImageRecognitionState();
}

class _ImageRecognitionState extends State<ImageRecognition> {
  late Database _database;
  List<Medicamento> _medicamentos = [];
  List? _outputs;
  File? _image;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    isLoading = true;
    _initDB().then((_) {
      loadModel().then((_) {
        setState(() {
          isLoading = false;
        });
      });
      fetchData();
    });
  }

  Future<void> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'medicamentos.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE medicamentos(id INTEGER PRIMARY KEY, name TEXT, dosis TEXT, contraindicaciones TEXT, uso TEXT)",
        );
      },
    );
  }

  Future<void> fetchData() async {
    var url = Uri.parse("http://192.168.100.35:8080/medicamentos/conn.php");
    var response = await http.get(url);
    if (response.statusCode == 200) {
      setState(() {
        _medicamentos = jsonDecode(response.body);
        isLoading = false;
      });
      for (var medicamento in _medicamentos) {
        print('Medicamento - Nombre: ${medicamento.name}, Dosis: ${medicamento.dosis}, Contraindicaciones: ${medicamento.contraindicaciones}, Uso: ${medicamento.uso}');
      }

      if (_medicamentos.isEmpty) {
        print('La lista de medicamentos está vacía.');
      } else {
        print('Se han cargado ${_medicamentos.length} medicamentos.');
      }
    } else {
      print('Error al obtener los datos: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teachable Machine"),
        centerTitle: true,
      ),
      body: isLoading
          ? Container(
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _image == null ? Container() : Image.file(_image!),
              SizedBox(height: 20.0),
              _outputs != null &&
                  _outputs!.isNotEmpty &&
                  _medicamentos.isNotEmpty
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Nombre: ${_medicamentos[_outputs![0]["index"]].name}",
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    "Dosis: ${_medicamentos[_outputs![0]["index"]].dosis}",
                    style: TextStyle(fontSize: 16.0),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    "Contraindicaciones: ${_medicamentos[_outputs![0]["index"]].contraindicaciones}",
                    style: TextStyle(fontSize: 16.0),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    "Uso: ${_medicamentos[_outputs![0]["index"]].uso}",
                    style: TextStyle(fontSize: 16.0),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    "Confidence: ${_outputs![0]["confidence"]}",
                    style: TextStyle(fontSize: 16.0),
                  ),
                ],
              )
                  : Container(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickedImage,
        child: const Icon(Icons.image),
      ),
    );
  }


  Future<void> loadModel() async {
    await Tflite.loadModel(
      model: "assets/model_unquant.tflite",
      labels: "assets/labels.txt",
    );
  }

  Future<void> pickedImage() async {
    final ImagePicker _picker = ImagePicker();
    var image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return null;
    }
    setState(() {
      isLoading = true;
      _image = File(image.path.toString());
    });
    classifyImage(File(image.path));
  }

  Future<void> classifyImage(File image) async {
    print('Classifying image...');
    var output = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 5,
      threshold: 0.5,
      imageMean: 127.5,
      imageStd: 127.5,
    );
    print('Classification complete.');

    if (output == null || output.isEmpty) {
      print('No output received from model.');
      return;
    }

    setState(() {
      isLoading = false;
      _outputs = output;
      print('Output: $_outputs');
      print('Predicted index: ${_outputs![0]["index"]}');
    });
  }


  @override
  void dispose() {
    Tflite.close();
    _database.close();
    super.dispose();
  }
}

class Medicamento {
  final int id;
  final String name;
  final String dosis;
  final String contraindicaciones;
  final String uso;

  Medicamento({
    required this.id,
    required this.name,
    required this.dosis,
    required this.contraindicaciones,
    required this.uso,
  });

  factory Medicamento.fromMap(Map<String, dynamic> map) {
    return Medicamento(
      id: map['id'],
      name: map['name'],
      dosis: map['dosis'],
      contraindicaciones: map['contraindicaciones'],
      uso: map['uso'],
    );
  }
}
