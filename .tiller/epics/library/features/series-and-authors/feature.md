# Series and Authors screens replace the placeholders

## Summary

The two screens the home screen has pointed at since stage 1 (direction doc "Placeholder entries"),
built from the book model's indexes.

## Behavior

- Series: a list of series with counts; tapping one shows its books in series order as a grid or list
  in the look, with the next unread marked.
- Authors: a list of authors with counts; tapping one shows their books.
- The launcher entries, the nav bar's Authors tab and the book sheet's "More by this author" row all
  resolve to these screens, and the placeholder note is deleted.
- Both screens draw with the look and carry the nav bar; goldens in both looks on the Colorsoft profile.

## Notes

Sorting authors by surname and handling multiple authors per book are specify-time rules.
