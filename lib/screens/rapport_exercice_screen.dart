import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

/// Rapport financier de l'exercice en cours : résumé, clôture, export PDF.
/// Accessible depuis l'espace trésorier (admin et trésorier).
class RapportExerciceScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const RapportExerciceScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<RapportExerciceScreen> createState() => _RapportExerciceScreenState();
}

class _RapportExerciceScreenState extends State<RapportExerciceScreen> {
  final GroupsService _groupsService = GroupsService();
  Map<String, dynamic>? _resume;
  List<Map<String, dynamic>> _mouvements = [];
  bool _isLoading = true;
  bool _isClosing = false;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resume = await _groupsService.fetchResumeExercice(widget.groupId);
      final mouvements = await _groupsService.fetchHistoriqueGroupe(
        groupId: widget.groupId,
        categorie: 'financier',
        limit: 100,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _resume = resume;
        _mouvements = mouvements;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _fmtMontant(dynamic value) {
    final num v = num.tryParse((value ?? '0').toString()) ?? 0;
    final neg = v < 0;
    final digits = v.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return '${neg ? '-' : ''}${buf.toString()} FCFA';
  }

  String _fmtDate(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString())?.toLocal();
    if (d == null) return '';
    final j = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$j/$m/${d.year}';
  }

  Future<void> _confirmerCloture() async {
    final r = _resume;
    if (r == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clôturer l'exercice ?"),
        content: Text(
          'Solde final : ${_fmtMontant(r['solde_actuel'])}\n'
          'Recettes : ${_fmtMontant(r['total_recettes'])}\n'
          'Dépenses : ${_fmtMontant(r['total_depenses'])}\n\n'
          'Cette action fige les chiffres de la période en cours et ouvre '
          'un nouvel exercice à partir de ce solde. Elle est définitive.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clôturer')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isClosing = true);
    try {
      await _groupsService.cloturerExercice(widget.groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercice clôturé — nouvel exercice ouvert')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  Future<void> _exporterPdf() async {
    final r = _resume;
    if (r == null) return;

    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();
      final genereLe = DateTime.now();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              widget.groupName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Rapport financier — exercice ouvert le ${_fmtDate(r['date_debut'])}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                _ligneResumePdf('Solde initial', _fmtMontant(r['solde_initial'])),
                _ligneResumePdf('Total recettes', _fmtMontant(r['total_recettes'])),
                _ligneResumePdf('Total dépenses', _fmtMontant(r['total_depenses'])),
                _ligneResumePdf('Solde actuel', _fmtMontant(r['solde_actuel']), gras: true),
                _ligneResumePdf(
                  'Opérations en attente',
                  '${r['operations_en_attente'] ?? 0}',
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text('Mouvements financiers', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(5),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cellulePdf('Date', gras: true),
                    _cellulePdf('Description', gras: true),
                    _cellulePdf('Montant', gras: true),
                  ],
                ),
                ..._mouvements.map((m) {
                  final apres = m['log_new_data'] is Map
                      ? Map<String, dynamic>.from(m['log_new_data'])
                      : <String, dynamic>{};
                  final montant = apres['montant'];
                  return pw.TableRow(children: [
                    _cellulePdf(_fmtDate(m['log_created_at'])),
                    _cellulePdf((m['log_description'] ?? '').toString()),
                    _cellulePdf(montant != null ? _fmtMontant(montant) : ''),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Généré le ${_fmtDate(genereLe)} via CaisseCom',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rapport_${widget.groupName}.pdf');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: 'rapport_${widget.groupName}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.TableRow _ligneResumePdf(String label, String valeur, {bool gras = false}) {
    return pw.TableRow(children: [
      _cellulePdf(label),
      _cellulePdf(valeur, gras: gras),
    ]);
  }

  pw.Widget _cellulePdf(String text, {bool gras = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  Widget _carteResume(String label, String valeur, {Color? couleur}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paperCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.muted.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 4),
            Text(
              valeur,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'serif',
                color: couleur ?? AppColors.forestDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.forestDark),
        title: const Text(
          'Rapport financier',
          style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text('Erreur : $_error', style: const TextStyle(color: AppColors.brick)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        widget.groupName,
                        style: const TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
                      ),
                      Text(
                        'Exercice ouvert le ${_fmtDate(_resume?['date_debut'])}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          _carteResume('Recettes', _fmtMontant(_resume?['total_recettes']), couleur: AppColors.success),
                          _carteResume('Dépenses', _fmtMontant(_resume?['total_depenses']), couleur: AppColors.brick),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _carteResume('Solde actuel', _fmtMontant(_resume?['solde_actuel'])),
                          _carteResume('En attente', '${_resume?['operations_en_attente'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isExporting ? null : _exporterPdf,
                          icon: _isExporting
                              ? const SizedBox(
                                  height: 14, width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: const Text('Exporter en PDF'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isClosing ? null : _confirmerCloture,
                          child: _isClosing
                              ? const SizedBox(
                                  height: 18, width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("Clôturer l'exercice"),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Mouvements de cet exercice',
                        style: TextStyle(fontSize: 14, fontFamily: 'serif', color: AppColors.forestDark),
                      ),
                      const SizedBox(height: 8),
                      ..._mouvements.map((m) {
                        final apres = m['log_new_data'] is Map
                            ? Map<String, dynamic>.from(m['log_new_data'])
                            : <String, dynamic>{};
                        final montant = apres['montant'];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (m['log_description'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 13, color: AppColors.ink),
                                    ),
                                    Text(
                                      _fmtDate(m['log_created_at']),
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              if (montant != null)
                                Text(
                                  _fmtMontant(montant),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}