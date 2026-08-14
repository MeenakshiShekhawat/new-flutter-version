// lib/features/product/presentation/widgets/product_details_widget.dart
// Converted from: component/ProductDetails.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_routes.dart';
import 'package:welfog/core/config/cdn_config.dart';
import '../../../../core/utils/top_toast.dart';
import 'package:geolocator/geolocator.dart';
import '../../../address/presentation/location_picker_screen.dart';

class ProductDetailsWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final String pincode;
  final VoidCallback? onRatingTap;
  final Future<void> Function(String slug)? onVariantSelected;

  // ignore: use_super_parameters
  const ProductDetailsWidget({
    Key? key,
    required this.data,
    required this.pincode,
    this.onRatingTap,
    this.onVariantSelected,
  }) : super(key: key);

  @override
  State<ProductDetailsWidget> createState() => _ProductDetailsWidgetState();
}

class _ProductDetailsWidgetState extends State<ProductDetailsWidget> {
  final TextEditingController _pincodeController = TextEditingController();
  String _deliveryMessage = '';
  String _errorMessage = '';
  bool _checkingDelivery = false;
  String _lastCheckedPin = '';
  dynamic _checkedPincodeDuration;
  bool _isBottomSheetOpen = false;

  int _apiTotalReviews = 0;
  double _apiRating = 0.0;
  int _totalRatings = 0;
  String? _loadingVariantSlug;

  @override
  void initState() {
    super.initState();
    _pincodeController.text = widget.pincode;

    // Pre-initialize values from widget details if available
    final rVal =
        widget.data['rating'] ?? widget.data['product']?['rating'] ?? 0.0;
    _apiRating = double.tryParse(rVal.toString()) ?? 0.0;

    final rawRc = widget.data['total_ratings'] ??
        widget.data['rating_count'] ??
        widget.data['ratings_count'] ??
        widget.data['product']?['total_ratings'] ??
        widget.data['product']?['rating_count'];
    _totalRatings = int.tryParse(rawRc?.toString() ?? '') ?? 0;

    _fetchReviews();
    if (widget.pincode.isNotEmpty) {
      _checkDelivery(widget.pincode);
    }
  }

  @override
  void didUpdateWidget(ProductDetailsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pincodeChanged = oldWidget.pincode != widget.pincode;
    final dataChanged = oldWidget.data != widget.data;
    if (pincodeChanged || dataChanged) {
      if (widget.pincode.isNotEmpty) {
        _pincodeController.text = widget.pincode;
        _checkDelivery(widget.pincode);
      }
    }
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchReviews() async {
    try {
      final productId = widget.data['id'];
      if (productId == null) return;

      final uri = Uri.parse(
          'https://welfogapi.welfog.com/api/v2/reviews/product_review/$productId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true && mounted) {
          setState(() {
            _apiTotalReviews =
                int.tryParse(data['total_reviews']?.toString() ?? '0') ?? 0;
            final rVal = widget.data['rating'] ??
                widget.data['product']?['rating'] ??
                0.0;
            _apiRating = double.tryParse(rVal.toString()) ?? 0.0;

            final rawRc = data['total_ratings'] ??
                data['rating_count'] ??
                data['ratings_count'] ??
                widget.data['total_ratings'] ??
                widget.data['rating_count'] ??
                widget.data['product']?['total_ratings'] ??
                widget.data['product']?['rating_count'];
            _totalRatings =
                int.tryParse(rawRc?.toString() ?? '') ?? _apiTotalReviews;
          });
        }
      }
    } catch (e) {
      debugPrint('Review API Error: $e');
    }
  }

  Future<Map<String, dynamic>> _checkDelivery(String pin, {bool fromSheet = false}) async {
    if (pin.trim().isEmpty) {
      if (!fromSheet || _isBottomSheetOpen) {
        setState(() {
          _errorMessage = 'Please enter a pincode first.';
          _deliveryMessage = '';
        });
      }
      return {
        'success': false,
        'message': 'Please enter a pincode first.',
      };
    }

    if (!fromSheet || _isBottomSheetOpen) {
      setState(() {
        _checkingDelivery = true;
        _lastCheckedPin = pin;
      });
    } else {
      setState(() {
        _checkingDelivery = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userIdStr = prefs.getString('user_id') ?? '';
      final accessToken = prefs.getString('access_token') ?? '';
      final dynamicShopLocationId =
          widget.data['location_id'] ?? widget.data['product']?['location_id'];

      // Parse IDs to numbers (int) if possible
      final dynamic userId =
          int.tryParse(userIdStr) ?? (userIdStr.isEmpty ? null : userIdStr);

      final shopLocationIdStr = (dynamicShopLocationId ?? '').toString();
      final dynamic shopLocationId = int.tryParse(shopLocationIdStr) ??
          (shopLocationIdStr.isEmpty ? null : shopLocationIdStr);

      final productIdStr = (widget.data['id'] ??
              widget.data['product']?['id'] ??
              widget.data['product_id'] ??
              '')
          .toString();
      final dynamic shopProductId = int.tryParse(productIdStr) ??
          (productIdStr.isEmpty ? null : productIdStr);

      // Parse coordinates to numbers (double) if possible
      final latVal = widget.data['shop_location']?['shop_latitude'] ??
          widget.data['product']?['shop_location']?['shop_latitude'];
      final lngVal = widget.data['shop_location']?['shop_longitude'] ??
          widget.data['product']?['shop_location']?['shop_longitude'];
      final dynamic shopLatitude =
          double.tryParse(latVal?.toString() ?? '') ?? latVal;
      final dynamic shopLongitude =
          double.tryParse(lngVal?.toString() ?? '') ?? lngVal;

      final payload = {
        'pincode': pin,
        'shop_latitude': shopLatitude,
        'shop_longitude': shopLongitude,
        'shop_product_id': shopProductId,
        'user_id': userId,
        'shop_location_id': shopLocationId,
      };

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final uri =
          Uri.parse('https://welfogapi.welfog.com/api/v2/pincode/check');

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          String msg =
              data['message'] ?? 'Product available for delivery';
          msg = msg.trim();
          if (msg.endsWith('!')) {
            msg = msg.substring(0, msg.length - 1).trim();
          }
          final duration = data['duration'] ?? data['data']?['duration'];
          if (!fromSheet || _isBottomSheetOpen) {
            if (mounted) {
              setState(() {
                _lastCheckedPin = pin;
                _deliveryMessage = msg;
                _errorMessage = '';
                _checkedPincodeDuration = duration;
              });
            }
          }
          return {
            'success': true,
            'message': msg,
            'duration': duration,
          };
        } else {
          if (!fromSheet || _isBottomSheetOpen) {
            if (mounted) {
              setState(() {
                _lastCheckedPin = pin;
                _errorMessage = 'Delivery not available to';
                _deliveryMessage = '';
                _checkedPincodeDuration = null;
              });
            }
            if (mounted) {
              TopToast.show(context, 'Delivery not available to $pin');
            }
          }
          return {
            'success': false,
            'message': 'Delivery not available to $pin',
          };
        }
      } else {
        if (!fromSheet || _isBottomSheetOpen) {
          if (mounted) {
            setState(() {
              _lastCheckedPin = pin;
              _errorMessage = 'Delivery not available to';
              _deliveryMessage = '';
              _checkedPincodeDuration = null;
            });
          }
          if (mounted) {
            TopToast.show(context, 'Delivery not available to $pin');
          }
        }
        return {
          'success': false,
          'message': 'Delivery not available to $pin',
        };
      }
    } catch (e) {
      if (!fromSheet || _isBottomSheetOpen) {
        if (mounted) {
          setState(() {
            _lastCheckedPin = pin;
            _errorMessage = 'Delivery not available to';
            _deliveryMessage = '';
            _checkedPincodeDuration = null;
          });
        }
        if (mounted) {
          TopToast.show(context, 'Delivery not available to $pin');
        }
      }
      return {
        'success': false,
        'message': 'Delivery not available to $pin',
      };
    } finally {
      if (mounted) {
        setState(() {
          _checkingDelivery = false;
        });
      }
    }
  }

  String _formatDeliveryTime(dynamic duration) {
    if (duration == null) return '2 - 4 days';
    final double? parsedVal = double.tryParse(duration.toString());
    if (parsedVal == null || parsedVal < 0) {
      return '2 - 4 days';
    }

    final int minutes = parsedVal.toInt();
    final int days = minutes ~/ 1440; // Math.floor(minutes / 1440)

    if (days > 0) {
      final int min = days;
      final int max = days + 1;
      return '$min - $max days';
    }

    final int hours = (minutes % 1440) ~/ 60;
    final int mins = minutes % 60;

    String result = '';
    if (hours > 0) {
      result += '$hours hr${hours > 1 ? 's' : ''}';
    }
    if (mins > 0) {
      result +=
          '${result.isNotEmpty ? ' ' : ''}$mins min${mins > 1 ? 's' : ''}';
    }

    return result.trim().isNotEmpty ? result.trim() : '0 min';
  }

  List<Color> _parseGradient(String colorVal) {
    try {
      final cleaned = colorVal
          .replaceAll(RegExp(r'linear-gradient\(|\)'), '')
          .split(',')
          .map((c) => c.trim())
          .where((c) => !c.startsWith('to ') && !c.endsWith('deg'))
          .toList();

      if (cleaned.length >= 2) {
        return cleaned.map((c) => _colorFromHex(c)).toList();
      }
    } catch (_) {}
    return [Colors.black, Colors.black];
  }

  Color _colorFromHex(String hexString) {
    try {
      final cleanHex = hexString.replaceAll('#', '').trim();

      // Handle standard CSS color name fallbacks
      final htmlColors = {
        'black': 0xFF000000,
        'white': 0xFFFFFFFF,
        'red': 0xFFFF0000,
        'green': 0xFF00FF00,
        'blue': 0xFF0000FF,
        'yellow': 0xFFFFE000,
        'cyan': 0xFF00FFFF,
        'magenta': 0xFFFF00FF,
        'gray': 0xFF808080,
        'grey': 0xFF808080,
        'orange': 0xFFFFA500,
        'pink': 0xFFFFC0CB,
        'purple': 0xFF800080,
        'brown': 0xFFA52A2A,
        'silver': 0xFFC0C0C0,
        'gold': 0xFFFFD700,
      };

      if (htmlColors.containsKey(cleanHex.toLowerCase())) {
        return Color(htmlColors[cleanHex.toLowerCase()]!);
      }

      final buffer = StringBuffer();
      if (cleanHex.length == 6 || cleanHex.length == 7) {
        buffer.write('ff');
      }
      buffer.write(cleanHex);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.grey.shade400; // Return a default color instead of crashing
    }
  }

  Widget _buildStockBadge(String statusText, Color bgColor, Color borderColor,
      Color textColor, bool isOutOfStock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOutOfStock
                  ? Colors.red
                  : (statusText.toLowerCase().contains('only')
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF16A34A)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Brand parsing
    final rawBrand = widget.data['brand_name'] ??
        widget.data['brandName'] ??
        widget.data['brand'] ??
        widget.data['Brand'] ??
        widget.data['brand_title'] ??
        widget.data['brandTitle'] ??
        widget.data['brand']?['name'] ??
        widget.data['brand']?['title'];

    String brandName = '';
    if (rawBrand != null) {
      final trimmed = rawBrand.toString().trim();
      final clean = trimmed
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll('-', '');
      if (clean.isNotEmpty &&
          clean != 'nobrand' &&
          clean != 'nonbrand' &&
          clean != 'nonbranded' &&
          clean != 'nobranded') {
        brandName = trimmed;
      }
    }

    final int stock;
    final stocksList = widget.data['stocks'];
    if (stocksList is List && stocksList.isNotEmpty) {
      final currentId = widget.data['id']?.toString();
      final matchingStock = stocksList.firstWhere(
        (s) => s is Map && s['product_id']?.toString() == currentId,
        orElse: () => null,
      );
      if (matchingStock != null) {
        stock = int.tryParse(matchingStock['qty']?.toString() ?? '0') ?? 0;
      } else {
        stock = int.tryParse(stocksList[0]?['qty']?.toString() ?? '0') ?? 0;
      }
    } else {
      final rawStock =
          widget.data['stock'] ?? widget.data['product']?['stock'] ?? 0;
      stock = int.tryParse(rawStock.toString()) ?? 0;
    }
    final bool isOutOfStock = stock <= 0;

    final String stockStatusText;
    final Color stockBgColor;
    final Color stockBorderColor;
    final Color stockTextColor;

    if (isOutOfStock) {
      stockStatusText = 'Out of Stock';
      stockBgColor = Colors.red.shade50;
      stockBorderColor = Colors.red.shade300;
      stockTextColor = Colors.red.shade600;
    } else if (stock <= 5) {
      stockStatusText = 'Only $stock Left';
      stockBgColor = const Color(0xFFFFF7ED); // amber 50
      stockBorderColor = const Color(0xFFFDBA74); // amber 300
      stockTextColor = const Color(0xFFEA580C); // amber 600
    } else {
      stockStatusText = 'In Stock';
      stockBgColor = const Color(0xFFF0FDF4); // green 50
      stockBorderColor = const Color(0xFF86EFAC); // green 300
      stockTextColor = const Color(0xFF16A34A); // green 600
    }

    final sellPrice = widget.data['final_price']?['sellPrice'] ??
        widget.data['product']?['final_price']?['sellPrice'] ??
        0.0;
    final mrpPrice = widget.data['final_price']?['mrpPrice'] ??
        widget.data['product']?['final_price']?['mrpPrice'] ??
        0.0;
    final discountPercentage = widget.data['final_price']
            ?['discountPercentage'] ??
        widget.data['product']?['final_price']?['discountPercentage'] ??
        0;

    final variants = widget.data['variant_products'] ??
        widget.data['product']?['variant_products'] as Map<String, dynamic>?;

    final bool isCheckDisabled = _checkingDelivery ||
        _pincodeController.text == _lastCheckedPin ||
        _pincodeController.text.length < 6;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Label
          if (brandName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Brand: $brandName',
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Title
          Padding(
            padding: EdgeInsets.only(top: brandName.isNotEmpty ? 1 : 2),
            child: Text(
              widget.data['name'] ?? widget.data['product']?['name'] ?? '',
              style: const TextStyle(
                color: Color(0xFF2B2B2B),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
          ),

          // Star rating reviews summary
          if (_apiTotalReviews > 0)
            GestureDetector(
              onTap: widget.onRatingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  children: [
                    Row(
                      children: List.generate(5, (idx) {
                        return Icon(
                          _apiRating >= idx + 1
                              ? Icons.star
                              : (_apiRating > idx
                                  ? Icons.star_half_rounded
                                  : Icons.star_border),
                          color: const Color(0xFFFFB800),
                          size: 14,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_apiRating.toStringAsFixed(1)} · $_totalRatings Ratings & Reviews',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Price info
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₹$sellPrice',
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (mrpPrice > sellPrice)
                            Flexible(
                              child: Text(
                                '₹$mrpPrice',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (discountPercentage > 0)
                            Text(
                              '$discountPercentage% OFF',
                              style: const TextStyle(
                                color: Color(0xFFFB5404),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStockBadge(stockStatusText, stockBgColor,
                    stockBorderColor, stockTextColor, isOutOfStock),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Inclusive of all taxes',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),

          // Check Delivery
          if (_lastCheckedPin.isEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check Delivery',
                  style: TextStyle(
                      color: Color(0xFF71717A), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                IntrinsicHeight(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFFFB5404), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: TextField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              buildCounter: (context,
                                      {required currentLength,
                                      required isFocused,
                                      maxLength}) =>
                                  null,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1F2937)),
                              onChanged: (value) {
                                setState(() {});
                              },
                              decoration: const InputDecoration(
                                hintText: 'Enter Pincode',
                                hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.normal),
                                counterText: '',
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 14),
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: isCheckDisabled || _checkingDelivery
                              ? null
                              : () => _checkDelivery(_pincodeController.text),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            decoration: BoxDecoration(
                              color: isCheckDisabled
                                  ? const Color(0xFFF3F4F6) // Muted background
                                  : const Color(0xFFFEF2EB), // peach background
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(23),
                                bottomRight: Radius.circular(23),
                              ),
                              border: const Border(
                                left: BorderSide(
                                    color: Color(0xFFE5E7EB), width: 1.2),
                              ),
                            ),
                            child: Text(
                              _checkingDelivery ? 'Checking...' : 'Apply',
                              style: TextStyle(
                                color: isCheckDisabled
                                    ? const Color(
                                        0xFF9CA3AF) // Muted text color
                                    : const Color(0xFFFB5404),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Divider stretched edge-to-edge
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return Transform.scale(
                      scaleX: screenWidth / (screenWidth - 40),
                      child: const Divider(
                          color: Color(0xFFE5E7EB), height: 1, thickness: 1),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _errorMessage.isNotEmpty
                              ? Colors.red.shade50
                              : const Color(0xFFFEF2EB), // peach background
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: _errorMessage.isNotEmpty
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFFB5404),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _errorMessage.isNotEmpty
                                  ? 'Delivery not available to'
                                  : 'Deliver to',
                              style: TextStyle(
                                color: _errorMessage.isNotEmpty
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF71717A),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _lastCheckedPin,
                              style: TextStyle(
                                color: _errorMessage.isNotEmpty
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1F2937),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _openPincodeBottomSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFB5404)),
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(
                              color: Color(0xFFFB5404),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_deliveryMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4), // Light green
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _deliveryMessage,
                                style: const TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Estimated Delivery ${_formatDeliveryTime(_checkedPincodeDuration ?? widget.data['shop_location']?['duration'] ?? widget.data['duration'] ?? widget.data['data']?['duration'] ?? widget.data['product']?['shop_location']?['duration'] ?? widget.data['product']?['duration'])}',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_errorMessage.isNotEmpty && _lastCheckedPin.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2), // Light red
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_errorMessage $_lastCheckedPin',
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Bottom Divider stretched edge-to-edge
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return Transform.scale(
                      scaleX: screenWidth / (screenWidth - 40),
                      child: const Divider(
                          color: Color(0xFFE5E7EB), height: 1, thickness: 1),
                    );
                  },
                ),
              ],
            ),
          ],

          // Pincode check responses (outside)
          if (_checkingDelivery ||
              (_errorMessage.isNotEmpty && _lastCheckedPin.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: _checkingDelivery
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFFB5404)),
                          ),
                          SizedBox(width: 8),
                          Text('Checking pincode...',
                              style: TextStyle(color: Color(0xFF4B5563))),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error,
                              color: Colors.red.shade600, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

          // Variants Section
          if (variants != null)
            ...(() {
              final list = variants.entries.where((entry) {
                final key = entry.key
                    .toLowerCase()
                    .replaceAll(RegExp(r'[\s_-]'), '')
                    .replaceAll('colour', 'color');
                return key != 'colorsizes' && key != 'colorsize';
              }).toList();

              // Sort list: put color first, size second
              list.sort((a, b) {
                final aKey = a.key.toLowerCase();
                final bKey = b.key.toLowerCase();
                final aIsColor =
                    aKey.contains('color') || aKey.contains('colour');
                final bIsColor =
                    bKey.contains('color') || bKey.contains('colour');

                if (aIsColor && !bIsColor) return -1;
                if (!aIsColor && bIsColor) return 1;
                return 0;
              });

              return list;
            }())
                .map((entry) {
              final String variantKey = entry.key;
              final rawVal = entry.value;
              final List<dynamic> variantValues = [];
              if (rawVal is List) {
                variantValues.addAll(rawVal);
              } else if (rawVal is Map) {
                variantValues.addAll(rawVal.values);
              }
              if (variantValues.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      variantKey,
                      style: const TextStyle(
                        color: Color(0xFF27272A),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: variantValues.length,
                      itemBuilder: (context, idx) {
                        final rawItem = variantValues[idx];
                        if (rawItem == null) return const SizedBox.shrink();
                        final Map<String, dynamic> item = rawItem is Map
                            ? Map<String, dynamic>.from(rawItem)
                            : {
                                'slug': rawItem.toString(),
                                'size': rawItem.toString(),
                                'color': rawItem.toString(),
                                'color_code': '#ccc',
                              };
                        final bool isSelected =
                            widget.data['slug'] == item['slug'];

                        // 1. SIZES LOGIC
                        if (variantKey.toLowerCase() == 'sizes' ||
                            variantKey.toLowerCase() == 'size' ||
                            item['size'] != null) {
                          return GestureDetector(
                            onTap: () async {
                              final targetSlug = item['slug']?.toString();
                              if (targetSlug != null &&
                                  targetSlug.isNotEmpty &&
                                  targetSlug != widget.data['slug']) {
                                if (widget.onVariantSelected != null) {
                                  setState(() {
                                    _loadingVariantSlug = targetSlug;
                                  });
                                  try {
                                    await widget.onVariantSelected!(targetSlug);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loadingVariantSlug = null;
                                      });
                                    }
                                  }
                                } else {
                                  Navigator.of(context).pushReplacementNamed(
                                    AppRoutes.product,
                                    arguments: targetSlug,
                                  );
                                }
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFEF6F1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFB5404)
                                      : const Color(0xFFD1D5DB),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: _loadingVariantSlug == item['slug']
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Color(0xFFFB5404)),
                                        ),
                                      )
                                    : Text(
                                        item['size'] ?? item['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFFFB5404)
                                              : const Color(0xFF1F2937),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        }

                        // 2. COLORS LOGIC
                        if (variantKey.toLowerCase() == 'colors' ||
                            variantKey.toLowerCase() == 'color') {
                          final colorValue =
                              item['color_code'] ?? item['color'] ?? '#ccc';
                          final colorName = item['color'] ?? 'Color';
                          final isGradient =
                              colorValue.toString().contains('linear-gradient');
                          final isSelectedColor = isSelected;

                          return GestureDetector(
                            onTap: () async {
                              final targetSlug = item['slug']?.toString();
                              if (targetSlug != null &&
                                  targetSlug.isNotEmpty &&
                                  targetSlug != widget.data['slug']) {
                                if (widget.onVariantSelected != null) {
                                  setState(() {
                                    _loadingVariantSlug = targetSlug;
                                  });
                                  try {
                                    await widget.onVariantSelected!(targetSlug);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loadingVariantSlug = null;
                                      });
                                    }
                                  }
                                } else {
                                  Navigator.of(context).pushReplacementNamed(
                                    AppRoutes.product,
                                    arguments: targetSlug,
                                  );
                                }
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelectedColor
                                    ? const Color(0xFFFEF6F1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelectedColor
                                      ? const Color(0xFFFB5404)
                                      : const Color(0xFFD1D5DB),
                                  width: isSelectedColor ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (_loadingVariantSlug == item['slug']) ...[
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFFFB5404)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ] else ...[
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                            width: 2),
                                        gradient: isGradient
                                            ? LinearGradient(
                                                colors: _parseGradient(
                                                    colorValue.toString()),
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              )
                                            : null,
                                        color: !isGradient
                                            ? _colorFromHex(
                                                colorValue.toString())
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    colorName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // 3. IMAGE THUMBNAILS
                        if (item['thumb'] != null) {
                          return GestureDetector(
                            onTap: () async {
                              final targetSlug = item['slug']?.toString();
                              if (targetSlug != null &&
                                  targetSlug.isNotEmpty &&
                                  targetSlug != widget.data['slug']) {
                                if (widget.onVariantSelected != null) {
                                  setState(() {
                                    _loadingVariantSlug = targetSlug;
                                  });
                                  try {
                                    await widget.onVariantSelected!(targetSlug);
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loadingVariantSlug = null;
                                      });
                                    }
                                  }
                                } else {
                                  Navigator.of(context).pushReplacementNamed(
                                    AppRoutes.product,
                                    arguments: targetSlug,
                                  );
                                }
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFB5404)
                                      : const Color(0xFF9CA3AF),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.network(
                                        CdnConfig.getImageUrl(item['thumb']),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image, size: 20),
                                      ),
                                    ),
                                    if (_loadingVariantSlug == item['slug'])
                                      Container(
                                        color: Colors.black38,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Color(0xFFFB5404)),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  void _openPincodeBottomSheet(BuildContext context) {
    _isBottomSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PincodeBottomSheetContent(
        initialPincode: _lastCheckedPin,
        checkingDelivery: _checkingDelivery,
        onApply: (pin) => _checkDelivery(pin, fromSheet: true),
      ),
    ).then((_) {
      _isBottomSheetOpen = false;
    });
  }
}

class _PincodeBottomSheetContent extends StatefulWidget {
  final String initialPincode;
  final bool checkingDelivery;
  final Future<Map<String, dynamic>> Function(String pincode) onApply;

  const _PincodeBottomSheetContent({
    required this.initialPincode,
    required this.checkingDelivery,
    required this.onApply,
  });

  @override
  State<_PincodeBottomSheetContent> createState() =>
      __PincodeBottomSheetContentState();
}

class __PincodeBottomSheetContentState
    extends State<_PincodeBottomSheetContent> {
  late final TextEditingController _controller;
  bool _isLoading = false;

  // Local state for checking status inside the bottom sheet
  String? _deliveryMessage;
  String? _errorMessage;
  dynamic _checkedPincodeDuration;

  // Local state for user saved addresses
  List<dynamic> _addresses = [];
  bool _loadingAddresses = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPincode);
    _controller.addListener(_onTextChanged);
    
    // Delay address fetching until the bottom sheet opening transition completes.
    // This prevents layout rebuilds from clashing with the slide-up animation,
    // eliminating any animation jank or "middle-pause" lag.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _fetchAddresses();
      }
    });
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final uri = Uri.parse(
        'https://welfogapi.welfog.com/api/v2/allAddress/$userId?id=$userId',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          final addData = data['addData'] as List? ?? [];
          if (mounted) {
            setState(() {
              _addresses = addData;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching addresses in bottom sheet: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAddresses = false);
      }
    }
  }

  Future<void> _selectSavedAddress(Map<String, dynamic> addr) async {
    final String id = (addr['id'] ?? '').toString();
    final String pincode = (addr['postal_code']?.toString() ?? '').trim();
    if (id.isEmpty) return;

    setState(() {
      _isLoading = true;
      _deliveryMessage = null;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      // Save locally
      await prefs.setString('latitude', addr['latitude']?.toString() ?? '0');
      await prefs.setString('longitude', addr['longitude']?.toString() ?? '0');
      await prefs.setString('city_name', addr['city_name']?.toString() ?? '');
      await prefs.setString('postal_code', pincode);

      final uri = Uri.parse(
        'https://welfogapi.welfog.com/api/v2/selectAnAddress/$id?id=$id&user_id=$userId',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true) {
          setState(() {
            _addresses = _addresses.map((a) {
              final mutable = Map<String, dynamic>.from(a as Map);
              if (mutable['id']?.toString() == id) {
                mutable['using_this'] = 1;
              } else {
                mutable['using_this'] = 0;
              }
              return mutable;
            }).toList();
          });

          _controller.text = pincode;
          _onTextChanged();
          await _handleCheckPincode(pincode);
          return;
        }
      }

      setState(() {
        _errorMessage = 'Failed to select address on server.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting address: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCheckPincode(String pin) async {
    final navigator = Navigator.of(context);
    setState(() {
      _isLoading = true;
      _deliveryMessage = null;
      _errorMessage = null;
    });

    try {
      final result = await widget.onApply(pin);
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            String msg =
                result['message'] ?? 'Product available for delivery';
            msg = msg.trim();
            if (msg.endsWith('!')) {
              msg = msg.substring(0, msg.length - 1).trim();
            }
            _deliveryMessage = msg;
            _checkedPincodeDuration = result['duration'];
            _errorMessage = null;
          } else {
            String errMsg =
                result['message'] ?? 'Delivery not available to $pin';
            errMsg = errMsg.trim();
            if (errMsg.endsWith('!')) {
              errMsg = errMsg.substring(0, errMsg.length - 1).trim();
            }
            _errorMessage = errMsg;
            _deliveryMessage = null;
          }
        });

        // If validation was successful, auto-dismiss the bottom sheet after a short delay (1.5 seconds)
        if (result['success'] == true) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (navigator.mounted) {
              navigator.pop();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error validating pincode: $e';
          _deliveryMessage = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _deliveryMessage = null;
      _errorMessage = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Location permission permanently denied. Enable in settings.';
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final double lat = position.latitude;
      final double lng = position.longitude;
      const String apiKey = "AIzaSyBcHzsB2kgoQa01PHIuYhVYeiCZlSiyXNo";
      final uri = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey",
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final firstResult = data['results'][0];
          final addressComponents = firstResult['address_components'] as List;

          String pincode = '';
          for (var comp in addressComponents) {
            final types = comp['types'] as List;
            if (types.contains('postal_code')) {
              pincode = comp['long_name']?.toString() ?? '';
              break;
            }
          }

          if (pincode.isNotEmpty) {
            _controller.text = pincode;
            _onTextChanged();
            await _handleCheckPincode(pincode);
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Pincode not found for current location.';
            });
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not resolve current location.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch location details.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error getting current location: $e';
      });
    }
  }

  Future<void> _handleSearchLocation() async {
    try {
      final selectedPincode = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LocationPickerScreen(
            forceGPS: true,
            pickPincodeOnly: true,
          ),
        ),
      );

      if (selectedPincode != null &&
          selectedPincode is String &&
          selectedPincode.isNotEmpty) {
        _controller.text = selectedPincode;
        _onTextChanged();
        await _handleCheckPincode(selectedPincode);
      }
    } catch (e) {
      debugPrint('Search Location Error: $e');
    }
  }

  String _formatDeliveryTime(dynamic duration) {
    if (duration == null) return '2 - 4 days';
    final double? parsedVal = double.tryParse(duration.toString());
    if (parsedVal == null || parsedVal < 0) {
      return '2 - 4 days';
    }

    final int minutes = parsedVal.toInt();
    final int days = minutes ~/ 1440;

    if (days > 0) {
      final int min = days;
      final int max = days + 1;
      return '$min - $max days';
    }

    final int hours = (minutes % 1440) ~/ 60;
    final int mins = minutes % 60;

    String result = '';
    if (hours > 0) {
      result += '$hours hr${hours > 1 ? 's' : ''}';
    }
    if (mins > 0) {
      result +=
          '${result.isNotEmpty ? ' ' : ''}$mins min${mins > 1 ? 's' : ''}';
    }

    return result.trim().isNotEmpty ? result.trim() : '0 min';
  }

  @override
  Widget build(BuildContext context) {
    final String currentInput = _controller.text.trim();
    final bool isCheckDisabled = _isLoading ||
        widget.checkingDelivery ||
        currentInput == widget.initialPincode ||
        currentInput.length < 6;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final double maxAllowedHeight = keyboardPadding > 0
        ? (screenHeight - keyboardPadding - 40).clamp(200.0, 450.0)
        : 450.0;
    final double sheetMinHeight = keyboardPadding > 0 ? 0.0 : maxAllowedHeight;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardPadding),
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(
              minHeight: sheetMinHeight,
              maxHeight: maxAllowedHeight,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Delivery Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF4B5563),
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Check Pincode',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFB5404),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter 6-digit Pincode',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: isCheckDisabled
                        ? null
                        : () => _handleCheckPincode(currentInput),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFB5404),
                              ),
                            )
                          : Text(
                              'Check',
                              style: TextStyle(
                                color: isCheckDisabled
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFFFB5404),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Check result details inside bottom sheet (placed directly below the text field)
            if (_deliveryMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4), // Light green
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _deliveryMessage!,
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Estimated Delivery ${_formatDeliveryTime(_checkedPincodeDuration)}',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), // Light red
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEE2E2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _isLoading ? null : _handleCurrentLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.my_location,
                            size: 18,
                            color: Color(0xFFFB5404),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Current Location',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _isLoading ? null : _handleSearchLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFFFB5404),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Search Location',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_loadingAddresses || _addresses.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Divider(
                      color: Color(0xFFE5E7EB),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      color: Color(0xFFE5E7EB),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ],

            if (_loadingAddresses) ...[
              const SizedBox(height: 8),
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFB5404),
                ),
              ),
            ] else if (_addresses.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                ' Select Saved Addresses',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    children: _addresses.map((addr) {
                      final bool isSelected =
                          addr['using_this'] == 1 || addr['using_this'] == '1';
                      final String name = addr['name']?.toString() ?? 'Address';
                      final String addressText = [
                        addr['address']?.toString() ?? '',
                        addr['city']?.toString() ?? '',
                        addr['state']?.toString() ?? '',
                        addr['postal_code']?.toString() ?? '',
                      ].where((s) => s.isNotEmpty).join(', ');

                      return GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => _selectSavedAddress(
                                Map<String, dynamic>.from(addr)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFFFB5404)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFB5404)
                                        : const Color(0xFFD1D5DB),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Center(
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFFFB5404)
                                            : const Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addressText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
      if (_isLoading)
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFB5404),
                ),
              ),
            ),
          ),
        ),
    ],
  ),
);
  }
}
