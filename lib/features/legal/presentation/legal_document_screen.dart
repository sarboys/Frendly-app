import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.documentId,
    this.backPath = '/welcome',
  });

  final String documentId;
  final String backPath;

  @override
  Widget build(BuildContext context) {
    final document = legalDocumentFor(documentId);
    return DateasyPhoneFrame(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 16,
          20,
          40,
        ),
        children: [
          _LegalHeader(backPath: backPath),
          const SizedBox(height: 24),
          if (document == null)
            const _MissingLegalDocument()
          else
            _LegalDocumentContent(document: document),
        ],
      ),
    );
  }
}

LegalDocument? legalDocumentFor(String id) {
  return _legalDocuments[id];
}

const _legalDocuments = <String, LegalDocument>{
  'terms': LegalDocument(
    title: 'Пользовательское соглашение (EULA)',
    updatedAt: 'Обновлено: 4 июня 2026',
    intro:
        'Это соглашение описывает правила использования Frendly до регистрации и после входа в приложение.',
    sections: [
      LegalSection(
        title: '1. Что такое Frendly',
        body:
            'Frendly помогает искать встречи, маршруты, чаты, знакомства, сообщества и городские активности. Сервис предназначен для личного использования пользователями 18 лет и старше.',
      ),
      LegalSection(
        title: '2. Аккаунт',
        body:
            'Пользователь отвечает за данные, которые указывает в профиле, и за действия в своем аккаунте. Нельзя выдавать себя за другого человека, создавать аккаунт для обхода блокировки или использовать чужие данные без согласия.',
      ),
      LegalSection(
        title: '3. Контент и встречи',
        body:
            'Пользователь отвечает за тексты, фото, сообщения, встречи и другой контент, который размещает в Frendly. Нельзя публиковать незаконный, опасный, обманный, дискриминационный, сексуальный или оскорбительный контент.',
      ),
      LegalSection(
        title: '4. Безопасность и модерация',
        body:
            'Frendly может скрывать контент, ограничивать доступ, удалять встречи, блокировать аккаунты и проверять жалобы, если есть риск для пользователей или нарушение правил. Пользователь может пожаловаться на профиль, встречу или другой контент внутри приложения.',
      ),
      LegalSection(
        title: '5. Подписки и покупки',
        body:
            'Платные функции, подписка Frendly+ и токены показываются до оплаты. На iOS покупки цифровых товаров проходят через Apple In-App Purchase. Условия, цена, период подписки и отмена отображаются перед подтверждением оплаты.',
      ),
      LegalSection(
        title: '6. Лицензия на приложение',
        body:
            'Frendly дает пользователю ограниченную, личную, непередаваемую и неэксклюзивную лицензию на использование приложения. Нельзя копировать приложение, пытаться извлечь исходный код, обходить защиту, продавать доступ или использовать сервис для вреда другим людям.',
      ),
      LegalSection(
        title: '7. EULA Apple',
        body:
            'Для iOS приложения также действует стандартное лицензионное соглашение Apple EULA, если оно применимо и не противоречит этому соглашению. Apple не отвечает за поддержку Frendly, пользовательский контент, встречи или споры между пользователями.',
      ),
      LegalSection(
        title: '8. Поддержка',
        body:
            'По вопросам аккаунта, безопасности, платежей и документов можно обратиться в поддержку Frendly через приложение или по контактам, указанным на сайте frendly.tech.',
      ),
    ],
  ),
  'privacy': LegalDocument(
    title: 'Политика конфиденциальности',
    updatedAt: 'Обновлено: 4 июня 2026',
    intro:
        'Здесь описано, какие данные Frendly получает и как использует их для работы приложения.',
    sections: [
      LegalSection(
        title: '1. Какие данные мы получаем',
        body:
            'Мы можем получать номер телефона, email, имя, возраст, город, фото, интересы, профиль, настройки, данные входа, сведения о подписке, токенах, встречах, сообществах, чатах, жалобах и действиях в приложении.',
      ),
      LegalSection(
        title: '2. Геолокация',
        body:
            'Если пользователь разрешает доступ к геолокации, Frendly использует ее для поиска ближайших встреч, маршрутов и городских рекомендаций. Пользователь может отключить доступ к геолокации в настройках устройства.',
      ),
      LegalSection(
        title: '3. Фото, сообщения и контент',
        body:
            'Фото, сообщения, голосовые записи, вложения, встречи и профильный контент используются для показа функций приложения, общения, модерации, безопасности и поддержки пользователей.',
      ),
      LegalSection(
        title: '4. Зачем нужны данные',
        body:
            'Данные нужны для регистрации, входа, показа профиля, встреч, чатов, знакомств, платежей, подписки, уведомлений, модерации, защиты от нарушений, поддержки и улучшения стабильности приложения.',
      ),
      LegalSection(
        title: '5. Кто может видеть данные',
        body:
            'Часть данных профиля, встреч и сообщений видна другим пользователям по логике приложения. Например, участники встречи могут видеть информацию о встрече и чат встречи. Закрытые данные не публикуются без необходимости для работы функции.',
      ),
      LegalSection(
        title: '6. Передача поставщикам',
        body:
            'Для работы приложения могут использоваться поставщики авторизации, пуш-уведомлений, платежей, аналитики, карт, хранения файлов и технической инфраструктуры. Им передаются только данные, которые нужны для соответствующей функции.',
      ),
      LegalSection(
        title: '7. Хранение и безопасность',
        body:
            'Мы применяем технические меры защиты и храним данные столько, сколько нужно для работы сервиса, соблюдения закона, безопасности, учета платежей и разрешения спорных ситуаций.',
      ),
      LegalSection(
        title: '8. Права пользователя',
        body:
            'Пользователь может запросить доступ к своим данным, исправление, удаление аккаунта или отзыв согласия, если это не мешает исполнению закона и защите других пользователей. Для запроса нужно обратиться в поддержку Frendly.',
      ),
    ],
  ),
  'community-rules': LegalDocument(
    title: 'Правила сообщества',
    updatedAt: 'Обновлено: 4 июня 2026',
    intro:
        'Эти правила помогают держать встречи, чаты и знакомства безопасными для всех пользователей.',
    sections: [
      LegalSection(
        title: '1. Реальные люди',
        body:
            'Используй свои данные и реальные фото. Нельзя выдавать себя за другого человека, создавать фейковые профили или вводить пользователей в заблуждение.',
      ),
      LegalSection(
        title: '2. Уважение',
        body:
            'Запрещены угрозы, травля, домогательства, ненависть, дискриминация, грубое давление, шантаж и публикация чужих личных данных.',
      ),
      LegalSection(
        title: '3. Запрещенный контент',
        body:
            'Нельзя публиковать незаконный контент, сексуальную эксплуатацию, насилие, инструкции для вреда, продажу запрещенных товаров, спам, мошенничество, порнографию или материалы с участием несовершеннолетних.',
      ),
      LegalSection(
        title: '4. Встречи',
        body:
            'Создавай встречи с понятным описанием, реальным местом и честными условиями участия. Нельзя использовать встречи для обмана, давления, опасных действий или коммерческого спама.',
      ),
      LegalSection(
        title: '5. Жалобы и блокировка',
        body:
            'Пользователь может пожаловаться на профиль, встречу или контент. После жалобы встреча может исчезнуть из ленты пользователя. Пользователь также может заблокировать другого пользователя, и его контент будет скрыт для заблокировавшего пользователя.',
      ),
      LegalSection(
        title: '6. Проверка жалоб',
        body:
            'Жалобы проверяются модерацией. Срочные вопросы безопасности получают приоритет, а обычные жалобы рассматриваются как можно быстрее, обычно в течение 24 часов.',
      ),
      LegalSection(
        title: '7. Последствия нарушений',
        body:
            'Frendly может удалить контент, скрыть встречу, ограничить функции, заблокировать профиль или передать информацию компетентным органам, если это нужно для защиты людей или исполнения закона.',
      ),
    ],
  ),
};

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.updatedAt,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final String intro;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader({required this.backPath});

  final String backPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          key: const ValueKey('legal-back-to-welcome'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go(backPath),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DateasyColors.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DateasyColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: DateasyColors.foreground,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Документы',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
        ),
      ],
    );
  }
}

class _LegalDocumentContent extends StatelessWidget {
  const _LegalDocumentContent({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          document.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: DateasyColors.foreground,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          document.updatedAt,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DateasyColors.muted,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 14),
        Text(
          document.intro,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.foreground,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 18),
        for (final section in document.sections) ...[
          _LegalSectionBlock(section: section),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _LegalSectionBlock extends StatelessWidget {
  const _LegalSectionBlock({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: DateasyColors.foreground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              section.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingLegalDocument extends StatelessWidget {
  const _MissingLegalDocument();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DateasyColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Документ не найден.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}
