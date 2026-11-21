import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/reports_viewmodel.dart';

/// Las URLs privadas viven en memoria y se renuevan al caducar o reabrir la app.
class RemoteReportImage extends StatefulWidget {
  const RemoteReportImage({
    super.key,
    required this.storagePath,
    required this.placeholder,
  });
  final String storagePath;
  final Widget placeholder;
  @override
  State<RemoteReportImage> createState() => _RemoteReportImageState();
}

class _RemoteReportImageState extends State<RemoteReportImage>
    with WidgetsBindingObserver {
  Future<String>? _url;
  Timer? _timer;
  bool _retried = false;
  int? _session;
  ImageProvider? _image;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reports = context.watch<ReportsViewModel>();
    if (_session != reports.sessionRevision) {
      _session = reports.sessionRevision;
      _retried = false;
      _forgetImage();
      _url = reports.photoUrl(widget.storagePath);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(RemoteReportImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _retried = false;
      _forgetImage();
      _url = context.read<ReportsViewModel>().photoUrl(widget.storagePath);
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (TickerMode.of(context)) {
      _timer = Timer(const Duration(seconds: 100), _refresh);
    }
  }

  void _refresh() {
    if (!mounted) return;
    _forgetImage();
    setState(() {
      _url = context.read<ReportsViewModel>().photoUrl(
        widget.storagePath,
        refresh: true,
      );
    });
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        TickerMode.of(context)) {
      _refresh();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _forgetImage();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _forgetImage() {
    final previous = _image;
    _image = null;
    if (previous != null) unawaited(previous.evict());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    // FutureBuilder conserva datos anteriores al cambiar de future. Una clave
    // nueva evita mostrar otra fotografía mientras se autoriza la siguiente.
    key: ObjectKey(_url),
    future: _url,
    builder: (context, snapshot) {
      Widget fallback() => Stack(
        fit: StackFit.expand,
        children: [
          widget.placeholder,
          Align(
            alignment: Alignment.bottomRight,
            child: IconButton.filledTonal(
              tooltip: 'Reintentar foto',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ),
        ],
      );
      if (snapshot.hasError) return fallback();
      if (!snapshot.hasData) return widget.placeholder;
      _image ??= ResizeImage.resizeIfNeeded(
        800,
        null,
        NetworkImage(snapshot.data!),
      );
      return Image(
        image: _image!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          if (!_retried) {
            _retried = true;
            final failedUrl = _url;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && identical(_url, failedUrl)) _refresh();
            });
          }
          return fallback();
        },
      );
    },
  );
}
