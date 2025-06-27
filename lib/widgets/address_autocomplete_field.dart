import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String labelText;
  final String hintText;
  final IconData? prefixIcon;
  final void Function(String)? onAddressSelected;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.validator,
    this.labelText = 'Address',
    this.hintText = 'Enter your address',
    this.prefixIcon,
    this.onAddressSelected,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  List<AddressSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  
  // Get API key from environment variables
  String get _apiKey {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Google Places API key not found. Please check your .env file.');
    }
    return apiKey;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text;
    
    if (query.length < 3) {
      _removeOverlay();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchPlaces(query);
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Delay hiding to allow for suggestion selection
      Future.delayed(const Duration(milliseconds: 150), () {
        _removeOverlay();
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (_apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      // For demo purposes, use mock data if no API key is set
      _showMockSuggestions(query);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=${Uri.encodeComponent(query)}&'
        'key=$_apiKey&'
        'types=(cities)&'  // Limit to cities for this use case
        'language=en'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List;
        
        setState(() {
          _suggestions = predictions
              .map((p) => AddressSuggestion(
                    description: p['description'],
                    placeId: p['place_id'],
                  ))
              .take(5) // Limit to 5 suggestions
              .toList();
        });
        
        _showOverlay();
      }
    } catch (e) {
      print('Error searching places: $e');
      // Fall back to mock data on error
      _showMockSuggestions(query);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMockSuggestions(String query) {
    // Mock suggestions for demo/development
    final mockCities = [
      'New York, NY, USA',
      'Los Angeles, CA, USA',
      'Chicago, IL, USA',
      'Houston, TX, USA',
      'Phoenix, AZ, USA',
      'Philadelphia, PA, USA',
      'San Antonio, TX, USA',
      'San Diego, CA, USA',
      'Dallas, TX, USA',
      'Austin, TX, USA',
    ];
    
    setState(() {
      _suggestions = mockCities
          .where((city) => city.toLowerCase().contains(query.toLowerCase()))
          .map((city) => AddressSuggestion(description: city, placeId: 'mock_$city'))
          .take(5)
          .toList();
    });
    
    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 48, // Account for padding
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 65), // Position below the text field
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    title: Text(
                      suggestion.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    onTap: () => _selectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    widget.controller.text = suggestion.description;
    widget.onAddressSelected?.call(suggestion.description);
    _removeOverlay();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
          suffixIcon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class AddressSuggestion {
  final String description;
  final String placeId;

  AddressSuggestion({
    required this.description,
    required this.placeId,
  });
} 