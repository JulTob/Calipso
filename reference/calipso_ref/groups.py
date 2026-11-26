"""Mirror of Calipso.Groups: vectors that lie near each other, put into groups.

Each group has a centre. Every vector joins the group whose centre is nearest;
then every centre moves to the middle of its group; and again, until nobody
changes group. The groups begin from vectors taken at even steps along the
list, so the result is always the same for the same list.
"""

from . import vectors

DEFAULT_PASSES = 20


def Distance_Squared(
        left: list,
        right: list
        ) -> float:
    apart = vectors.Subtracted(left, right)
    return vectors.Dot(apart, apart)


def Start_Centres(
        points: list,
        count: int
        ) -> list:
    centres = []
    for group in range(1, count + 1):
        centres.append(list(points[((group - 1) * len(points)) // count]))
    return centres


def Nearest(
        point: list,
        centres: list
        ) -> int:
    #-- The number of the nearest centre, counted from 1. On a tie, the first.
    best = 1
    least = Distance_Squared(point, centres[0])
    for group in range(2, len(centres) + 1):
        distance = Distance_Squared(point, centres[group - 1])
        if distance < least:
            best = group
            least = distance
    return best


def Middle_Of(
        points: list,
        numbers: list,
        group: int,
        old_centre: list
        ) -> list:
    #-- The middle of the members of one group. A group with no members keeps its centre.
    total = [0.0] * len(old_centre)
    members = 0
    for place in range(0, len(points)):
        if numbers[place] == group:
            total = vectors.Added(total, points[place])
            members = members + 1
    if members == 0:
        return old_centre
    return vectors.Scaled(1.0 / float(members), total)


def Grouped(
        points: list,
        count: int,
        passes: int = DEFAULT_PASSES
        ) -> list:
    #-- The group of each point, counted from 1. Never more groups than points.
    if len(points) == 0:
        return []
    kept = min(count, len(points))
    centres = Start_Centres(points, kept)
    numbers = [0] * len(points)
    for _ in range(0, passes):
        changed = False
        for place in range(0, len(points)):
            group = Nearest(points[place], centres)
            if group != numbers[place]:
                numbers[place] = group
                changed = True
        if not changed:
            break
        for group in range(1, kept + 1):
            centres[group - 1] = Middle_Of(points, numbers, group, centres[group - 1])
    return numbers
