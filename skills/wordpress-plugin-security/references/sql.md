# Safe SQL with `$wpdb`

## Always prepare

```php
$wpdb->get_results( $wpdb->prepare(
    "SELECT ID, post_title FROM {$wpdb->posts}
     WHERE post_author = %d AND post_status = %s
     ORDER BY post_date DESC LIMIT %d",
    $author_id, 'publish', 10
) );
```

Placeholders:

| Placeholder | For |
|---|---|
| `%d` | integer |
| `%f` | float |
| `%s` | string |
| `%i` | identifier (table/column name, WP 6.2+) |

## `IN()` clauses

`prepare()` does not handle arrays for `IN()` directly. Build placeholders dynamically:

```php
$ids = array_map( 'intval', $ids );
$placeholders = implode( ',', array_fill( 0, count( $ids ), '%d' ) );

$wpdb->get_results( $wpdb->prepare(
    "SELECT * FROM {$wpdb->posts} WHERE ID IN ($placeholders)",
    ...$ids
) );
```

## Dynamic columns / tables

Use `%i` (WP 6.2+):

```php
$wpdb->prepare( "SELECT %i FROM %i WHERE ID = %d", $column, $table, $id );
```

If on older WP, validate against an allowlist before interpolation:

```php
$allowed_columns = array( 'post_title', 'post_date', 'post_author' );
if ( ! in_array( $column, $allowed_columns, true ) ) {
    return new WP_Error( 'bad_column', 'Invalid column' );
}
$sql = "SELECT $column FROM {$wpdb->posts} WHERE ID = %d";
$wpdb->get_var( $wpdb->prepare( $sql, $id ) );
```

## Dynamic ORDER BY direction

```php
$dir = ( strtoupper( $dir ) === 'DESC' ) ? 'DESC' : 'ASC';
```

Hardcode the two possibilities; never interpolate user input.

## LIKE with wildcards

```php
$like = '%' . $wpdb->esc_like( $term ) . '%';
$wpdb->prepare( "SELECT * FROM {$wpdb->posts} WHERE post_title LIKE %s", $like );
```

`esc_like` escapes `%` and `_` so they are taken literally.

## `insert` / `update` / `delete`

These methods accept arrays and handle preparation:

```php
$wpdb->insert(
    $table,
    array( 'post_id' => $post_id, 'meta_key' => 'foo', 'meta_value' => $value ),
    array( '%d',                 '%s',                 '%s' )
);
```

The format array is the type matrix — pass it explicitly even though it's optional, so an unintended type change can't sneak in.

## Error handling

```php
$wpdb->suppress_errors( false );
$result = $wpdb->query( $wpdb->prepare( '...' ) );

if ( false === $result ) {
    error_log( 'DB error: ' . $wpdb->last_error );
    return new WP_Error( 'db_error', 'Database error' );
}
```

Do **not** surface `$wpdb->last_error` to end users — it can reveal table structure.

## Mistakes to flag

- Any SQL string with `{$var}` or `.$var` interpolating user input → SQLi.
- `$wpdb->query( "SELECT ... WHERE foo = '$val'" )` → SQLi.
- `prepare()` with a single argument and no placeholders → no-op, still vulnerable.
- Building `ORDER BY` direction from `$_GET` → use a hardcoded allowlist.
- Wrapping `%s` in extra quotes inside the SQL string (`"WHERE x = '%s'"`) → corrupts escaping. `prepare()` adds the quotes for you.
