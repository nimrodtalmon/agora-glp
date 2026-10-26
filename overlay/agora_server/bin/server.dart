// AGORA live server: runs the compiled AGORA platform (four agents, alice,
// bob, carol and dave, in one GLP heap, programs/vglp/cva/agora_live) and is
// every person: it keeps what each person's dispatcher draws and injects the
// person's grants, input(Id, Path, R), from the web page.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:glp_runtime/multiagent/agent_runtime.dart';
import 'package:glp_runtime/runtime/terms.dart' as rt;

final persons = ['alice', 'bob', 'carol', 'dave'];

class World {
  late AgentRuntime agent;
  // person -> construct id -> drawn term (JSON)
  final Map<String, Map<int, Object?>> draws = {for (final p in persons) p: {}};
  final List<Object?> net = [];
  final List<String> transcript = [];
  int version = 0;
  int outMicros = 0, injectMicros = 0;
  String status = 'starting';
  Future<void> queue = Future.value();

  Future<void> start(String root) async {
    agent = AgentRuntime(
      agentId: 'host',
      program: '$root/programs/vglp/cva/agora_live',
      rootSelfGlpPath: '$root/programs/self.glp',
      goalLabel: 'agora_ui/3',
    );
    agent.maxQuiescenceCycles = 5000000;
    agent.onUserOutput = (t) {
      final sw = Stopwatch()..start();
      _onOut(toJson(agent.derefTerm(t)));
      outMicros += sw.elapsedMicroseconds;
    };
    agent.onOutput = (line) {
      transcript.add(line);
      if (transcript.length > 300) transcript.removeAt(0);
    };
    await agent.initialize();
    status = 'ready';
    version++;
  }

  void _onOut(Object? j) {
    if (j is Map && j['f'] == 'd') {
      final args = j['a'] as List;
      final who = args[0] as String;
      final draw = args[1];
      if (draw is Map && draw['f'] == 'draw') {
        final a = draw['a'] as List;
        draws[who]![a[0] as int] = a[2];
      } else if (draw is Map && draw['f'] == 'withdraw') {
        draws[who]!.remove((draw['a'] as List)[0] as int);
      }
    } else if (j is Map && j['f'] == 'net') {
      net.add((j['a'] as List)[0]);
      if (net.length > 500) net.removeAt(0);
    }
    version++;
  }

  Future<void> act(String who, int id, List<int> path, Object? value) {
    final term = rt.StructTerm('in', [
      rt.ConstTerm(who),
      rt.StructTerm('input', [rt.ConstTerm(id), listOf(path.map((i) => rt.ConstTerm(i)).toList()), fromJson(value)]),
    ]);
    final done = queue.then((_) async {
      final sw = Stopwatch()..start();
      await agent.injectUserInput(term);
      injectMicros += sw.elapsedMicroseconds;
    });
    queue = done.catchError((e) { transcript.add('ERROR $e'); });
    return done;
  }

  Map<String, Object?> state() => {
        'version': version,
        'status': status,
        'persons': {for (final p in persons) p: draws[p]!.map((k, v) => MapEntry('$k', v))},
        'timing': {'out_ms': outMicros ~/ 1000, 'inject_ms': injectMicros ~/ 1000},
        'net': net.length > 60 ? net.sublist(net.length - 60) : net,
      };
}

rt.Term listOf(List<rt.Term> items) =>
    items.reversed.fold<rt.Term>(rt.ConstTerm(rt.nil), (tail, x) => rt.StructTerm('.', [x, tail]));

// JSON form of a term: a constant its value, the empty list [], a list a JSON
// array, a structure {"f": functor, "a": [args]}, an unbound variable {"v": 1}.
Object? toJson(rt.Term t) {
  if (t is rt.ConstTerm) {
    if (t.value == rt.nil || t.value == null) return <Object?>[];
    final v = t.value;
    if (v is num || v is String || v is bool) return v;
    return v.toString();
  }
  if (t is rt.StructTerm) {
    if (t.functor == '.' && t.args.length == 2) {
      final out = <Object?>[];
      rt.Term cur = t;
      while (cur is rt.StructTerm && cur.functor == '.' && cur.args.length == 2) {
        out.add(toJson(cur.args[0]));
        cur = cur.args[1];
      }
      if (!(cur is rt.ConstTerm && (cur.value == rt.nil || cur.value == null))) {
        out.add({'tail': toJson(cur)});
      }
      return out;
    }
    return {'f': t.functor, 'a': [for (final a in t.args) toJson(a)]};
  }
  return {'v': 1};
}

rt.Term fromJson(Object? j) {
  if (j is List) return listOf([for (final x in j) fromJson(x)]);
  if (j is Map) return rt.StructTerm(j['f'] as String, [for (final a in (j['a'] as List)) fromJson(a)]);
  return rt.ConstTerm(j);
}

Future<void> main(List<String> args) async {
  final root = Platform.environment['GLP_ROOT'] ?? Directory.current.parent.path;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final webDir = '${Platform.environment['WEB_DIR'] ?? '$root/agora_server/web'}';
  var world = World();
  unawaited(world.start(root));

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('AGORA server on port $port (GLP root $root)');
  await for (final req in server) {
    unawaited(_handle(req, () => world, (w) => world = w, root, webDir));
  }
}

Future<void> _handle(HttpRequest req, World Function() getWorld, void Function(World) setWorld, String root, String webDir) async {
    var world = getWorld();
    try {
      final path = req.uri.path;
      final appKey = Platform.environment['APP_KEY'] ?? '';
      if (appKey.isNotEmpty && path.startsWith('/api/') &&
          req.uri.queryParameters['key'] != appKey) {
        req.response.statusCode = 403;
        req.response.write('access key required');
        await req.response.close();
        return;
      }
      if (path == '/api/state') {
        final since = int.tryParse(req.uri.queryParameters['since'] ?? '') ?? -1;
        // long poll: wait up to 20s for a change
        final until = DateTime.now().add(const Duration(seconds: 20));
        while (world.version == since && DateTime.now().isBefore(until)) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
        _json(req, world.state());
      } else if (path == '/api/act' && req.method == 'POST') {
        final body = jsonDecode(await utf8.decodeStream(req)) as Map;
        await world.act(body['person'] as String, body['id'] as int,
            [for (final x in body['path'] as List) x as int], body['value']);
        _json(req, {'ok': true});
      } else if (path == '/api/reset' && req.method == 'POST') {
        world = World();
        setWorld(world);
        await world.start(root);
        _json(req, {'ok': true});
      } else if (path == '/api/transcript') {
        _json(req, world.transcript);
      } else {
        final f = File('$webDir${path == '/' ? '/index.html' : path}');
        if (await f.exists() && !path.contains('..')) {
          req.response.headers.contentType = path.endsWith('.js')
              ? ContentType('application', 'javascript', charset: 'utf-8')
              : ContentType.html;
          await req.response.addStream(f.openRead());
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      }
    } catch (e, st) {
      stderr.writeln('$e\n$st');
      try {
        req.response.statusCode = 500;
        req.response.write('$e');
        await req.response.close();
      } catch (_) {}
    }
}

void _json(HttpRequest req, Object? o) {
  req.response.headers.contentType = ContentType.json;
  req.response.headers.set('Cache-Control', 'no-store');
  req.response.write(jsonEncode(o));
  req.response.close();
}
