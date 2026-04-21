import 'dart:async';
import 'package:flutter/material.dart';
import '../models/osm_place_suggestion.dart';

/// A search field that shows live suggestions as the user types,
/// with debouncing to avoid hammering the Nominatim API.
class OsmSearchBar extends StatefulWidget {
  /// Called (debounced) when the user types — use this to fetch suggestions.
  final Future<List<OsmPlaceSuggestion>> Function(String query) onSuggest;

  /// Called when the user taps a suggestion or presses Search/Enter.
  final void Function(OsmPlaceSuggestion suggestion) onSelected;

  /// Fallback called when the user hits Search with freeform text (no suggestion).
  final void Function(String query) onFreeSearch;

  /// Placeholder text inside the field.
  final String hint;

  /// Debounce delay. Defaults to 400 ms — a good balance for Nominatim.
  final Duration debounce;

  const OsmSearchBar({
    super.key,
    required this.onSuggest,
    required this.onSelected,
    required this.onFreeSearch,
    this.hint = 'Search for a place…',
    this.debounce = const Duration(milliseconds: 400),
  });

  @override
  State<OsmSearchBar> createState() => _OsmSearchBarState();
}

class _OsmSearchBarState extends State<OsmSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<OsmPlaceSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;

  // When a suggestion is selected, we set this flag so that the next
  // onChanged (caused by setting controller.text) is ignored.
  bool _suppressNext = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Hide suggestions when focus leaves the field
        setState(() => _suggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Input handling ───────────────────────────────────────────────────────

  void _onChanged(String val) {
    if (_suppressNext) {
      _suppressNext = false;
      return;
    }

    _debounce?.cancel();

    if (val.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _loadingSuggestions = false;
      });
      return;
    }

    setState(() => _loadingSuggestions = true);

    _debounce = Timer(widget.debounce, () async {
      final results = await widget.onSuggest(val);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _loadingSuggestions = false;
        });
      }
    });
  }

  void _selectSuggestion(OsmPlaceSuggestion s) {
    _debounce?.cancel();
    _suppressNext = true;
    _controller.text = s.shortName;
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
      _loadingSuggestions = false;
    });
    widget.onSelected(s);
  }

  void _triggerFreeSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _debounce?.cancel();
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
      _loadingSuggestions = false;
    });
    widget.onFreeSearch(query);
  }

  void _clearField() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _suggestions = [];
      _loadingSuggestions = false;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextField(context),
        if (_suggestions.isNotEmpty || _loadingSuggestions)
          _buildSuggestionsPanel(context),
      ],
    );
  }

  Widget _buildTextField(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onChanged,
      onSubmitted: (_) => _triggerFreeSearch(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: _loadingSuggestions
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: _clearField,
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSuggestionsPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _loadingSuggestions && _suggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  indent: 56,
                ),
                itemBuilder: (_, i) =>
                    _SuggestionTile(
                      suggestion: _suggestions[i],
                      onTap: () => _selectSuggestion(_suggestions[i]),
                    ),
              ),
      ),
    );
  }
}

// ── Single suggestion row ────────────────────────────────────────────────────

class _SuggestionTile extends StatelessWidget {
  final OsmPlaceSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({required this.suggestion, required this.onTap});

  IconData get _icon {
    switch (suggestion.category) {
      case 'city':
      case 'town':
      case 'village':
        return Icons.location_city;
      case 'country':
        return Icons.flag_outlined;
      case 'airport':
        return Icons.flight;
      case 'station':
      case 'railway':
        return Icons.train;
      case 'hotel':
      case 'hostel':
        return Icons.hotel;
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
        return Icons.restaurant;
      case 'park':
      case 'garden':
        return Icons.park;
      case 'hospital':
      case 'clinic':
        return Icons.local_hospital;
      case 'school':
      case 'university':
        return Icons.school;
      case 'museum':
      case 'tourism':
      case 'attraction':
        return Icons.museum;
      case 'beach':
        return Icons.beach_access;
      case 'road':
      case 'street':
      case 'path':
        return Icons.add_road;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.shortName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      suggestion.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.north_west,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
