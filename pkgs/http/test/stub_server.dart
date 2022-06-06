// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/src/utils.dart';
import 'package:stream_channel/stream_channel.dart';

void hybridMain(StreamChannel<dynamic> channel) async {
  final server = await HttpServer.bind('localhost', 0);
  final url = Uri.http('localhost:${server.port}', '');
  server.listen((request) async {
    var path = request.uri.path;
    var response = request.response;

    if (path == '/error') {
      response
        ..statusCode = 400
        ..contentLength = 0;
      unawaited(response.close());
      return;
    }

    if (path == '/loop') {
      var n = int.parse(request.uri.query);
      response
        ..statusCode = 302
        ..headers.set('location', url.resolve('/loop?${n + 1}').toString())
        ..contentLength = 0;
      unawaited(response.close());
      return;
    }

    if (path == '/redirect') {
      response
        ..statusCode = 302
        ..headers.set('location', url.resolve('/').toString())
        ..contentLength = 0;
      unawaited(response.close());
      return;
    }

    if (path == '/no-content-length') {
      response
        ..statusCode = 200
        ..contentLength = -1
        ..write('body');
      unawaited(response.close());
      return;
    }

    var requestBodyBytes = await ByteStream(request).toBytes();
    var encodingName = request.uri.queryParameters['response-encoding'];
    var outputEncoding =
        encodingName == null ? ascii : requiredEncodingForCharset(encodingName);

    response.headers.contentType =
        ContentType('application', 'json', charset: outputEncoding.name);
    response.headers.set('single', 'value');

    dynamic requestBody;
    if (requestBodyBytes.isEmpty) {
      requestBody = null;
    } else if (request.headers.contentType?.charset != null) {
      var encoding =
          requiredEncodingForCharset(request.headers.contentType!.charset!);
      requestBody = encoding.decode(requestBodyBytes);
    } else {
      requestBody = requestBodyBytes;
    }

    final headers = <String, List<String>>{};

    request.headers.forEach((name, values) {
      // These headers are automatically generated by dart:io, so we don't
      // want to test them here.
      if (name == 'cookie' || name == 'host') return;

      headers[name] = values;
    });

    var content = <String, dynamic>{
      'method': request.method,
      'path': request.uri.path,
      if (requestBody != null) 'body': requestBody,
      'headers': headers,
    };

    var body = json.encode(content);
    response
      ..contentLength = body.length
      ..write(body);
    unawaited(response.close());
  });
  channel.sink.add(server.port);
}