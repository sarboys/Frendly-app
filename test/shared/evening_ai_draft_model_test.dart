import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';

void main() {
  test('parses AI route step image variants', () {
    final draft = EveningAiDraftData.fromJson({
      'draftId': 'draft-1',
      'route': {
        'id': 'route-1',
        'title': 'Маршрут',
        'steps': [
          {
            'title': 'Brix',
            'imageUrl': 'https://cdn.test/brix.jpg',
            'imageVariants': {
              'card': {
                'url': 'https://cdn.test/brix__card.webp',
                'width': 720,
                'height': 540,
              },
            },
          },
        ],
      },
    });

    final step = draft.route.steps.single;

    expect(step.imageUrl, 'https://cdn.test/brix.jpg');
    expect(step.imageVariants, {
      'card': {
        'url': 'https://cdn.test/brix__card.webp',
        'width': 720,
        'height': 540,
      },
    });
  });

  test('parses AI route step match metadata', () {
    final draft = EveningAiDraftData.fromJson({
      'draftId': 'draft-1',
      'route': {
        'id': 'route-1',
        'title': 'Маршрут',
        'steps': [
          {
            'title': 'BeerMood',
            'matchQuality': 'substitution',
            'matchedTraits': ['place:bar'],
            'missingTraits': ['set:cocktails'],
            'avoidHits': ['set:craft_beer'],
            'substitutionReason':
                'Коктейли не подтверждены. Подобрали ближайший бар.',
          },
        ],
      },
    });

    final step = draft.route.steps.single;

    expect(step.matchQuality, 'substitution');
    expect(step.matchedTraits, ['place:bar']);
    expect(step.missingTraits, ['set:cocktails']);
    expect(step.avoidHits, ['set:craft_beer']);
    expect(
      step.substitutionReason,
      'Коктейли не подтверждены. Подобрали ближайший бар.',
    );
  });

  test('maps AI draft backend errors to readable messages', () {
    final requestOptions = RequestOptions(path: '/evening/routes/ai-drafts');

    final candidatesError = BackendActionException.fromDio(
      DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {
            'code': 'evening_ai_candidates_not_found',
            'message': 'Route candidates not found',
          },
        ),
      ),
    );
    final regenerateError = BackendActionException.fromDio(
      DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 409,
          data: {
            'code': 'evening_ai_regenerate_candidates_exhausted',
            'message': 'Not enough alternative candidates to regenerate route',
          },
        ),
      ),
    );
    final exactPlaceError = BackendActionException.fromDio(
      DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {
            'code': 'evening_ai_exact_place_not_available',
            'message': 'Ресторан «Аврора» пока не подключен к партнерской программе',
            'details': {
              'requestedName': 'Аврора',
              'role': 'place_food',
            },
          },
        ),
      ),
    );

    expect(candidatesError.message, 'Не нашёл подходящие места под запрос');
    expect(regenerateError.message, 'Нет другой подходящей замены');
    expect(
      exactPlaceError.message,
      'Ресторан «Аврора» пока не подключен к партнерской программе',
    );
  });

  test('maps AI draft network failure to readable message', () {
    final requestOptions = RequestOptions(path: '/evening/routes/ai-drafts');

    final exception = BackendActionException.fromDio(
      DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.receiveTimeout,
      ),
    );

    expect(exception.message, 'Backend не ответил. Попробуй ещё раз');
  });
}
