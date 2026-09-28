"""Build model/catalog.json from the inventory report (development tool)."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
inventory = json.loads((root/'reports'/'model_inventory.json').read_text(encoding='utf-8'))
conversion = json.loads((root/'reports'/'conversion.json').read_text(encoding='utf-8'))
rows = [
    ('Object_126Action.001', 'Дверь водителя', 'Поворот передней левой двери вокруг узла петель.', 'door'),
    ('Object_93Action.001', 'Открытие капота', 'Подъём капота. Обратного закрытия в исходном клипе нет.', 'front'),
    ('Object_91Action.001', 'Задний борт', 'Откидывание заднего борта грузовой платформы.', 'rear'),
    ('Object_68Action', 'Поворот прожектора', 'Поворот дополнительного прожектора у водительской стойки.', 'door'),
    ('Object_221Action', 'Заднее левое колесо', 'Вращение одного колеса. В исходнике узел назван wheel_lf, но геометрически это заднее левое колесо. Это не езда всей машины.', 'rear'),
    ('Object_242Action.001', 'Переднее левое колесо', 'Вращение и смена ориентации одного колеса из-под второго корня сцены.', 'front'),
    ('door_dside_f_28Action', 'Поза группы двери', 'Один ключ на кадре 2. Неподвижная поза, а не анимация открытия.', 'door'),
    ('Object_245Action', 'Поза переднего правого колеса', 'Один ключ на кадре 0. Колесо не движется.', 'front'),
]
items = []
for name, title, description, view in rows:
    action = next(a for a in inventory['actions'] if a['name'] == name)
    start, end = action['frame_range']
    items.append({
        'id': name, 'title': title, 'description': description, 'view': view, 'kind': 'source',
        'duration': round((end - start) / inventory['scene']['fps'], 6), 'frames': [start, end],
        'fps': inventory['scene']['fps'], 'channels': len(action['curves']),
        'keys': sum(len(c['keys']) for c in action['curves']),
        'dynamic_channels': sum(1 for c in action['curves'] if c['sample_max'] is not None and c['sample_max'] - c['sample_min'] > 1e-6),
    })
for clip in [
    ('demo-steering', 'Поворачивание руля', 'Добавлено программно: реальный узел руля вращается вокруг оси, вычисленной по геометрии рулевого колеса. Камера «Руль» скрывает кузов для осмотра.', 4, 'steering'),
    ('demo-forward', 'Езда вперёд', 'Добавлено программно: вся модель движется прямо, четыре колеса вращаются, камера следует за машиной. Не симуляция физики.', 6, 'front'),
    ('demo-right', 'Поворот направо', 'Добавлено программно: движение по дуге вправо с поворотом передних колёс и руля. Кинематическая демонстрация, не игровой контроллер.', 6, 'front')]:
    items.append({'id': clip[0], 'title': clip[1], 'description': clip[2], 'kind': 'demo',
                  'duration': clip[3], 'view': clip[4], 'fps': inventory['scene']['fps']})
catalog = {'summary': inventory['summary'], 'preview_triangles': conversion['triangles_preview'], 'items': items}
(root/'model'/'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding='utf-8')
print('items', len(items))
